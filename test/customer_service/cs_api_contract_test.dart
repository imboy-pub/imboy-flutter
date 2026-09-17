/// 客服 API 客户端契约单测（mock adapter）——W2 冻结合同补充
///
/// 契约依据（contracts-w2.md · W2-APP 消费的合同）：
/// - CS 访客发消息不再接受 key_ref（提交即 422
///   unexpected_argument.key_ref）；app 侧所有 CS 提交面必须保持
///   键白名单，任何 key_ref 键漂移即回归；
/// - profile PATCH 不再接受 profile_cipher/profile_key_version——
///   CsApi 无 PATCH 面（客户端 compile-time 事实），本测试钉住全部
///   提交面键集合，任何键漂移即回归；
/// - 其余 W2 新端点（平台管理面 /api/adm/*）不进 app，客户端不得调用。
///
/// 测试原理镜像 enterprise_api_contract_test：注入"记录请求 + 恒返指定
/// 响应"的 HttpClientAdapter；adapterForTest 只对**之后构造**的实例生效，
/// 故每个用例先换 adapter、用例内现建 CsApi、用例结束恢复。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/public.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart'
    show EnterpriseSenderType;
import 'package:imboy/service/storage.dart';

const String sessionId = '7266418340025468940';

/// 记录请求并恒返指定 statusCode + JSON envelope 的出口。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  /// 每次请求的 (method, path, data, queryParameters)
  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

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
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
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

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  _RecordingAdapter useAdapter(int statusCode, Map<String, dynamic> body) {
    final adapter = _RecordingAdapter(statusCode, body);
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    return adapter;
  }

  group('W2 客服 API 提交面契约（新合同：无 key_ref）', () {
    test('queue：GET 排队列表，解析 session_id/contact_id 为 TSID string', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'list': [
              {
                'session_id': 7266418340025468940,
                'contact_id': 7266418340025468941,
                'contact_name': '访客甲',
                'waiting_since': '1789000000000',
              },
            ],
          },
        ),
      );
      final api = CsApi();

      final items = await api.queue();

      expect(adapter.requests, hasLength(1));
      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      expect(req.$2, '/api/v1/cs/sessions/queue');
      expect(req.$4, isEmpty);
      expect(items.single.sessionId, '7266418340025468940');
      expect(items.single.contactId, '7266418340025468941');
    });

    test(
      'claim/close：CAS POST 带 {expected_version}（close 可选 reason）',
      () async {
        final adapter = useAdapter(200, okEnvelope());
        final api = CsApi();

        // A0 冻结参数表：claim/close 的 expected_version 均必填（CSM-01 补
        // claim、CSM-02 补 close）；reason 可选且经 csSanitizeCloseReason 清洗。
        await api.claim(sessionId, expectedVersion: 7);
        await api.close(sessionId, expectedVersion: 8);
        await api.close(sessionId, expectedVersion: 8, reason: '已解决');

        expect(adapter.requests, hasLength(3));
        final (claimMethod, claimPath, claimData, _) = adapter.requests[0];
        expect(claimMethod, 'POST');
        expect(claimPath, '/api/v1/cs/sessions/$sessionId/claim');
        final claimBody = Map<String, dynamic>.from(claimData as Map);
        expect(claimBody.keys.toSet(), {'expected_version'});
        expect(claimBody['expected_version'], 7);

        final (closeMethod, closePath, closeData, _) = adapter.requests[1];
        expect(closeMethod, 'POST');
        expect(closePath, '/api/v1/cs/sessions/$sessionId/close');
        expect(Map<String, dynamic>.from(closeData as Map).keys.toSet(), {
          'expected_version',
        });

        // reason 空缺时不出现键；给出时键白名单 {expected_version, reason}
        final (m3, _, d3, _) = adapter.requests[2];
        expect(m3, 'POST');
        final body3 = Map<String, dynamic>.from(d3 as Map);
        expect(body3.keys.toSet(), {'expected_version', 'reason'});
        expect(body3['reason'], '已解决');
      },
    );

    test('sessionDetail：GET /api/v1/cs/sessions/:id，回显投影宽容解析', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'session_id': 7266418340025468940,
            'organization_id': 7266418340025468901,
            'conversation_id': 7266418340025468950,
            'status': 'active',
            'version': 9,
            'rating': 0,
            'contact_id': 7266418340025468941,
            'business_identity_id': 7266418340025468902,
          },
        ),
      );
      final api = CsApi();

      final detail = await api.sessionDetail(sessionId);

      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      expect(req.$2, '/api/v1/cs/sessions/$sessionId');
      expect(detail.sessionId, sessionId);
      expect(detail.organizationId, '7266418340025468901');
      expect(detail.conversationId, '7266418340025468950');
      expect(detail.status, 'active');
      expect(detail.version, 9);
      expect(detail.hasRating, isFalse);
      expect(detail.assigneeIdentityId, '7266418340025468902');
    });

    test('conversationMessages：A0 坐席读路径 + after_id/limit 游标，裸数组解析', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: [
            {
              'id': 7266418340025468960,
              'conversation_id': 7266418340025468950,
              'organization_id': 7266418340025468901,
              'sender_type': 'contact',
              'sender_contact_id': 7266418340025468941,
              'sender_business_identity_id': null,
              'content': '订单还没收到',
              'delivered': false,
            },
          ],
        ),
      );
      final api = CsApi();

      final messages = await api.conversationMessages(
        '7266418340025468950',
        afterId: '7266418340025468959',
        limit: 20,
      );

      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      // A0 冻结坐席读路径（无 /organizations/ 段）
      expect(
        req.$2,
        '/api/v1/enterprise/conversations/7266418340025468950/messages',
      );
      expect(req.$4, {'after_id': '7266418340025468959', 'limit': 20});
      expect(messages.single.id, '7266418340025468960');
      expect(messages.single.senderType, EnterpriseSenderType.contact);
      expect(messages.single.senderXorValid, isTrue);
    });

    test('sendConversationMessage：EB 写真源提交面键白名单（幂等 client_msg_id）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'id': 7266418340025468961,
            'conversation_id': 7266418340025468950,
            'organization_id': 7266418340025468901,
            'sender_type': 'business_identity',
            'sender_contact_id': null,
            'sender_business_identity_id': 7266418340025468902,
            'content': '您好，正在为您核实',
          },
        ),
      );
      final api = CsApi();

      final sent = await api.sendConversationMessage(
        '7266418340025468901',
        '7266418340025468950',
        body: '您好，正在为您核实',
        clientMsgId: 'cmid-1',
        identityId: '7266418340025468902',
      );

      final req = adapter.requests.single;
      expect(req.$1, 'POST');
      expect(
        req.$2,
        '/api/v1/enterprise/organizations/7266418340025468901'
        '/conversations/7266418340025468950/messages',
      );
      final body = Map<String, dynamic>.from(req.$3 as Map);
      expect(body.keys.toSet(), {
        'client_msg_id',
        'sender_type',
        'body',
        'identity_id',
      });
      expect(body['client_msg_id'], 'cmid-1');
      expect(body['sender_type'], 'business_identity');
      // F-SEC-02 负例：提交面不得出现 content/asset_id 旧键形
      expect(body.containsKey('content'), isFalse);
      expect(sent.id, '7266418340025468961');
      expect(sent.senderType, EnterpriseSenderType.businessIdentity);
    });

    test('ackDelivery：delivery-only，recipient_ref 必填（EB 合同）', () async {
      final adapter = useAdapter(200, okEnvelope());
      final api = CsApi();

      await api.ackDelivery(
        '7266418340025468901',
        '7266418340025468950',
        '7266418340025468960',
        recipientRef: 'seat:7266418340025468902',
      );

      final req = adapter.requests.single;
      expect(req.$1, 'POST');
      expect(
        req.$2,
        '/api/v1/enterprise/organizations/7266418340025468901'
        '/conversations/7266418340025468950/messages/7266418340025468960/ack',
      );
      final body = Map<String, dynamic>.from(req.$3 as Map);
      expect(body.keys.toSet(), {'recipient_ref'});
      expect(body['recipient_ref'], 'seat:7266418340025468902');
    });

    test('queuePage：键集分页 query 仅含非空 after_id/limit（A0 冻结键名）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'sessions': [
              {
                'session_id': 7266418340025468950,
                'contact_id': 7266418340025468951,
                'version': 3,
              },
            ],
            'next_after_id': '7266418340025468950',
            'total': 12,
          },
        ),
      );
      final api = CsApi();

      // 第二页请求（带 after_id 游标）
      await api.queuePage(afterId: '7266418340025468940', limit: 20);

      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      expect(req.$2, '/api/v1/cs/sessions/queue');
      expect(req.$4, {'after_id': '7266418340025468940', 'limit': 20});
      // 首页（无游标）不得携带 after_id（仅 limit）
      final first = await api.queuePage(limit: kCsQueuePageSize);
      final firstReq = adapter.requests[1];
      expect(firstReq.$4, {'limit': 20});
      expect(first.items.single.sessionId, '7266418340025468950');
      expect(first.nextAfterId, '7266418340025468950');
      expect(first.hasMore, isTrue);
      expect(first.total, 12);
      expect(req.$3, isNull);
    });

    test(
      'transfer：CAS body 键白名单 == {to_identity_id, expected_version}',
      () async {
        final adapter = useAdapter(200, okEnvelope());
        final api = CsApi();

        // CSM-02 §12.5.1：A0 冻结参数表（cs_actions:session_transfer）要求
        // to_identity_id 与 expected_version 均必填。
        await api.transfer(
          sessionId,
          toIdentityId: '7266418340025468942',
          expectedVersion: 6,
        );

        expect(adapter.requests, hasLength(1));
        final req = adapter.requests.single;
        expect(req.$1, 'POST');
        expect(req.$2, '/api/v1/cs/sessions/$sessionId/transfer');
        final body = Map<String, dynamic>.from(req.$3 as Map);
        expect(body.keys.toSet(), {'to_identity_id', 'expected_version'});
        expect(body['to_identity_id'], '7266418340025468942');
        expect(body['expected_version'], 6);
      },
    );

    test('rate：body 键白名单 == {rating, expected_version}', () async {
      final adapter = useAdapter(200, okEnvelope());
      final api = CsApi();

      await api.rate(sessionId, rating: 5, expectedVersion: 7);

      expect(adapter.requests, hasLength(1));
      final req = adapter.requests.single;
      expect(req.$1, 'POST');
      expect(req.$2, '/api/v1/cs/sessions/$sessionId/rating');
      final body = Map<String, dynamic>.from(req.$3 as Map);
      expect(body.keys.toSet(), {'rating', 'expected_version'});
      expect(body['rating'], 5);
      expect(body['expected_version'], 7);
    });

    test('错误映射：401/403/409 镜像 EnterpriseApiException 判定属性', () async {
      useAdapter(401, {'code': 401, 'msg': 'unauthorized'});
      var api = CsApi();
      var e401 = await _capture(() => api.claim(sessionId, expectedVersion: 1));
      expect(e401, isA<CsApiException>());
      expect((e401! as CsApiException).isUnauthorized, isTrue);

      // 403：坐席被 suspend 后写操作被拒（降级只读）
      useAdapter(403, {'code': 403, 'msg': 'forbidden'});
      api = CsApi();
      var e403 = await _capture(() => api.claim(sessionId, expectedVersion: 1));
      expect((e403! as CsApiException).isForbidden, isTrue);

      useAdapter(409, {'code': 409, 'msg': 'offboarding_required'});
      api = CsApi();
      var e409 = await _capture(() => api.claim(sessionId, expectedVersion: 1));
      expect((e409! as CsApiException).isOffboardingRequired, isTrue);
      expect((e409 as CsApiException).isConflict, isTrue);
    });
  });

  group('W2 全量提交面负例（新合同防回归钉）', () {
    test('全部 CS 动作提交面：无 key_ref / 无任何密文形键 / 无 PATCH 动词', () async {
      final adapter = useAdapter(200, okEnvelope());
      final api = CsApi();

      await api.claim(sessionId, expectedVersion: 2);
      await api.close(sessionId, expectedVersion: 3, reason: '已解决');
      await api.transfer(sessionId, toIdentityId: 'x', expectedVersion: 3);
      await api.rate(sessionId, rating: 4, expectedVersion: 3);

      // 全量收集提交面 body
      final bodies = adapter.requests
          .map((r) => r.$3)
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      for (final body in bodies) {
        // 新合同负例一：CS 访客发消息提交即 422 unexpected_argument.key_ref
        // → 客户端任何提交面不得出现 key_ref
        expect(
          body.containsKey('key_ref'),
          isFalse,
          reason: '新合同：提交面出现 key_ref 即 422，属回归',
        );
        // 新合同负例二：profile_cipher / profile_key_version 已下线
        expect(body.containsKey('profile_cipher'), isFalse);
        expect(body.containsKey('profile_key_version'), isFalse);
        // 兜底：任何密文形键一律拒绝
        expect(
          body.keys.where(
            (k) => k.endsWith('_cipher') || k.endsWith('_key_version'),
          ),
          isEmpty,
        );
      }

      // 全量请求动词负例：CS 客户端不得出现 PATCH（profile PATCH 面
      // 已下线；W2 新端点均为只读列表且不进 app）
      expect(
        adapter.requests.every((r) => r.$1 != 'PATCH'),
        isTrue,
        reason: 'CsApi 不得存在 PATCH 提交面（profile_cipher 已下线）',
      );
    });
  });
}

/// 捕获业务异常（fail-closed 契约：失败必须抛而非空兜底）
Future<Object?> _capture(Future<Object?> Function() fn) async {
  try {
    final r = await fn();
    return StateError('expected throw, got $r');
  } on Object catch (e) {
    return e;
  }
}
