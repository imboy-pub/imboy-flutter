/// 客服 API 客户端契约单测（mock adapter）——api-surface-freeze（T-2 裁定）
///
/// 契约依据（API-SURFACE-FREEZE-V1 · APP-M01）：
/// - 坐席端点全部 **org 作用域**（路径显式 organization_id，服务端逐字
///   校验 path org == session.org == 坐席 active member org）：
///   `GET /api/v1/cs/me/seat-contexts`（唯一主体作用域端点，无 org 键）、
///   `GET /api/v1/cs/organizations/:org_id/sessions/queue`、
///   `GET /api/v1/cs/organizations/:org_id/seats/sessions?status=active|closed`、
///   `GET /api/v1/cs/organizations/:org_id/sessions/:id`、
///   `GET /api/v1/cs/organizations/:org_id/transfer-targets`、
///   `POST .../sessions/:id/claim|transfer|close`；
/// - 历史漂移负例：无 org 段的 `/api/v1/cs/sessions/...` 路径**不得出现**
///   （T-2 后服务端已不注册）；rating 是访客面（cs_visit 主体），CsApi
///   无评分提交面；
/// - CS 访客发消息不再接受 key_ref（提交即 422）；app 侧所有 CS 提交面
///   必须保持键白名单；profile PATCH 面（profile_cipher/profile_key_version）
///   已下线——CsApi 无 PATCH 面。
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

const String orgId = '7266418340025468901';
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

  group('APP-M01 坐席上下文（seat-contexts，主体作用域）', () {
    test('seatContexts：GET 无 org 键路径 + 无 query；解析每 Org 投影', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'contexts': [
              {
                'organization_id': 7266418340025468901,
                'organization_name': '示例组织',
                'workspaces': [
                  {'id': 7266418340025468921, 'name': '默认工作区'},
                ],
                'business_identity_id': 7266418340025468902,
                'seat_enabled': true,
                'capabilities': ['conversation.read', 'conversation.write'],
              },
              {
                'organization_id': 7266418340025468999,
                'organization_name': '停用席位组织',
                'workspaces': <Map<String, dynamic>>[],
                'business_identity_id': 7266418340025468903,
                'seat_enabled': false,
                'capabilities': <String>[],
              },
            ],
            'user_id': 7266418340025468800,
          },
        ),
      );
      final api = CsApi();

      final result = await api.seatContexts();

      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      // 主体作用域端点：路径无 org 段、无 query
      expect(req.$2, '/api/v1/cs/me/seat-contexts');
      expect(req.$4, isEmpty);
      // TSID 一律 String（safeParseBigIntJson 语义）
      expect(result.userId, '7266418340025468800');
      expect(result.contexts, hasLength(2));

      final eligible = result.contexts[0];
      expect(eligible.organizationId, '7266418340025468901');
      expect(eligible.organizationName, '示例组织');
      expect(eligible.workspaces.single.id, '7266418340025468921');
      expect(eligible.workspaces.single.name, '默认工作区');
      expect(eligible.businessIdentityId, '7266418340025468902');
      expect(eligible.seatEnabled, isTrue);
      expect(eligible.capabilities, contains('conversation.read'));
      expect(eligible.isEligible, isTrue, reason: 'assignment + enabled seat');

      final disabled = result.contexts[1];
      expect(disabled.seatEnabled, isFalse);
      expect(disabled.capabilities, isEmpty);
      expect(disabled.isEligible, isFalse, reason: 'disabled seat → 不可用坐席上下文');
    });

    test('seatContexts：payload 缺 contexts 键 → 空列表（fail-closed 不炸）', () async {
      useAdapter(200, okEnvelope(payload: <String, dynamic>{}));
      final api = CsApi();

      final result = await api.seatContexts();
      expect(result.contexts, isEmpty);
    });
  });

  group('APP-M01 org 作用域列表（queue / seats/sessions，键集分页）', () {
    test('queuePage：org 在路径，query 仅含非空 after_id/limit', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'sessions': [
              {'session_id': 7266418340025468950, 'version': 3},
            ],
            'next_after_id': '7266418340025468950',
            'total': 12,
            'total_by_status': {'queued': 12},
          },
        ),
      );
      final api = CsApi();

      // 第二页请求（带 after_id 游标）
      await api.queuePage(orgId, afterId: '7266418340025468940', limit: 20);

      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      // T-2 权威路径：org 显式在路径
      expect(req.$2, '/api/v1/cs/organizations/$orgId/sessions/queue');
      expect(req.$4, {'after_id': '7266418340025468940', 'limit': 20});

      // 首页（无游标）不得携带 after_id（仅 limit）
      final first = await api.queuePage(orgId, limit: kCsQueuePageSize);
      final firstReq = adapter.requests[1];
      expect(firstReq.$4, {'limit': 20});
      expect(first.items.single.sessionId, '7266418340025468950');
      expect(first.nextAfterId, '7266418340025468950');
      expect(first.hasMore, isTrue);
      expect(first.total, 12);
      expect(req.$3, isNull);
    });

    test(
      'seatSessionsPage：seats/sessions 路径 + status 必填（active/closed）',
      () async {
        final adapter = useAdapter(
          200,
          okEnvelope(
            payload: {
              'sessions': [
                {
                  'id': 7266418340025468955,
                  'business_identity_id': 7266418340025468902,
                  'status': 'active',
                },
              ],
              'next_after_id': null,
              'total': 3,
              'total_by_status': {'active': 3},
            },
          ),
        );
        final api = CsApi();

        final page = await api.seatSessionsPage(
          orgId,
          status: 'active',
          limit: 20,
        );

        final req = adapter.requests.single;
        expect(req.$1, 'GET');
        expect(req.$2, '/api/v1/cs/organizations/$orgId/seats/sessions');
        expect(req.$4, {'status': 'active', 'limit': 20});
        expect(page.items.single.sessionId, '7266418340025468955');
        expect(page.items.single.assigneeIdentityId, '7266418340025468902');
        expect(page.total, 3);

        await api.seatSessionsPage(
          orgId,
          status: 'closed',
          afterId: '7266418340025468954',
        );
        final closedReq = adapter.requests[1];
        expect(closedReq.$4, {
          'status': 'closed',
          'after_id': '7266418340025468954',
        });
      },
    );

    test('transferTargets：transfer-targets 路径 + targets 键解析', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'targets': [
              {
                'business_identity_id': 7266418340025468903,
                'display_name': '客服乙',
                'available': true,
              },
              {
                'business_identity_id': 7266418340025468904,
                'display_name': '客服丙',
                'available': false,
              },
            ],
            'next_after_id': null,
          },
        ),
      );
      final api = CsApi();

      final page = await api.transferTargets(orgId);

      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      expect(req.$2, '/api/v1/cs/organizations/$orgId/transfer-targets');
      expect(page.items, hasLength(2));
      expect(page.items[0].identityId, '7266418340025468903');
      expect(page.items[0].displayName, '客服乙');
      expect(page.items[0].available, isTrue);
      expect(page.items[1].available, isFalse);
      expect(page.hasMore, isFalse);
    });
  });

  group('APP-M01 org 作用域动作与详情（CAS）', () {
    test(
      'claim/close：org 在路径，CAS POST 带 {expected_version}（close 可选 reason）',
      () async {
        final adapter = useAdapter(
          200,
          okEnvelope(
            payload: {
              'session_id': 7266418340025468940,
              'status': 'active',
              'version': 8,
              'business_identity_id': 7266418340025468902,
            },
          ),
        );
        final api = CsApi();

        // A0 冻结参数表：claim/close 的 expected_version 均必填（CSM-01 补
        // claim、CSM-02 补 close）；reason 可选且经 csSanitizeCloseReason 清洗。
        final claimResult = await api.claim(
          orgId,
          sessionId,
          expectedVersion: 7,
        );
        await api.close(orgId, sessionId, expectedVersion: 8);
        await api.close(orgId, sessionId, expectedVersion: 8, reason: '已解决');

        expect(adapter.requests, hasLength(3));
        final (claimMethod, claimPath, claimData, _) = adapter.requests[0];
        expect(claimMethod, 'POST');
        expect(
          claimPath,
          '/api/v1/cs/organizations/$orgId/sessions/$sessionId/claim',
        );
        final claimBody = Map<String, dynamic>.from(claimData as Map);
        expect(claimBody.keys.toSet(), {'expected_version'});
        expect(claimBody['expected_version'], 7);
        // claim 回显 = 权威经办身份（APP-M01-A04）
        expect(claimResult.assigneeIdentityId, '7266418340025468902');
        expect(claimResult.status, 'active');
        expect(claimResult.version, 8);

        final (closeMethod, closePath, closeData, _) = adapter.requests[1];
        expect(closeMethod, 'POST');
        expect(
          closePath,
          '/api/v1/cs/organizations/$orgId/sessions/$sessionId/close',
        );
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

    test('sessionDetail：org 在路径，回显投影宽容解析', () async {
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

      final detail = await api.sessionDetail(orgId, sessionId);

      final req = adapter.requests.single;
      expect(req.$1, 'GET');
      expect(req.$2, '/api/v1/cs/organizations/$orgId/sessions/$sessionId');
      expect(detail.sessionId, sessionId);
      expect(detail.organizationId, '7266418340025468901');
      expect(detail.conversationId, '7266418340025468950');
      expect(detail.status, 'active');
      expect(detail.version, 9);
      expect(detail.hasRating, isFalse);
      expect(detail.assigneeIdentityId, '7266418340025468902');
    });

    test(
      'transfer：org 在路径，CAS body 键白名单 == {to_identity_id, expected_version}',
      () async {
        final adapter = useAdapter(200, okEnvelope());
        final api = CsApi();

        // CSM-02 §12.5.1：A0 冻结参数表（cs_actions:session_transfer）要求
        // to_identity_id 与 expected_version 均必填。
        await api.transfer(
          orgId,
          sessionId,
          toIdentityId: '7266418340025468942',
          expectedVersion: 6,
        );

        expect(adapter.requests, hasLength(1));
        final req = adapter.requests.single;
        expect(req.$1, 'POST');
        expect(
          req.$2,
          '/api/v1/cs/organizations/$orgId/sessions/$sessionId/transfer',
        );
        final body = Map<String, dynamic>.from(req.$3 as Map);
        expect(body.keys.toSet(), {'to_identity_id', 'expected_version'});
        expect(body['to_identity_id'], '7266418340025468942');
        expect(body['expected_version'], 6);
      },
    );

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
        // APP-M02-A01：recipient_ref 恒为 identity:<business_identity_id>
        //（`seat:` 前缀=后端 400 契约，客户端绝不产生——本用例钉唯一合法形状）。
        recipientRef: 'identity:7266418340025468902',
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
      expect(body['recipient_ref'], 'identity:7266418340025468902');
    });

    test('错误映射：401/403/409 镜像 EnterpriseApiException 判定属性', () async {
      useAdapter(401, {'code': 401, 'msg': 'unauthorized'});
      var api = CsApi();
      var e401 = await _capture(
        () => api.claim(orgId, sessionId, expectedVersion: 1),
      );
      expect(e401, isA<CsApiException>());
      expect((e401! as CsApiException).isUnauthorized, isTrue);

      // 403：坐席被 suspend 后写操作被拒（降级只读）
      useAdapter(403, {'code': 403, 'msg': 'forbidden'});
      api = CsApi();
      var e403 = await _capture(
        () => api.claim(orgId, sessionId, expectedVersion: 1),
      );
      expect((e403! as CsApiException).isForbidden, isTrue);

      useAdapter(409, {'code': 409, 'msg': 'offboarding_required'});
      api = CsApi();
      var e409 = await _capture(
        () => api.claim(orgId, sessionId, expectedVersion: 1),
      );
      expect((e409! as CsApiException).isOffboardingRequired, isTrue);
      expect((e409 as CsApiException).isConflict, isTrue);
    });
  });

  group('APP-M01 全量提交面负例（新合同防回归钉）', () {
    test('全路径负例：无 org 段的 /api/v1/cs/sessions/... 历史路径不得出现（T-2）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'contexts': <Map<String, dynamic>>[],
            'sessions': <Map<String, dynamic>>[],
            'targets': <Map<String, dynamic>>[],
          },
        ),
      );
      final api = CsApi();

      await api.seatContexts();
      await api.queuePage(orgId, limit: 5);
      await api.seatSessionsPage(orgId, status: 'active', limit: 5);
      await api.transferTargets(orgId, limit: 5);
      await api.sessionDetail(orgId, sessionId);
      await api.claim(orgId, sessionId, expectedVersion: 1);
      await api.transfer(
        orgId,
        sessionId,
        toIdentityId: 'x',
        expectedVersion: 1,
      );
      await api.close(orgId, sessionId, expectedVersion: 1);

      for (final req in adapter.requests) {
        expect(
          req.$2.startsWith('/api/v1/cs/sessions/'),
          isFalse,
          reason: 'T-2 后坐席面路径必须 org 作用域，裸 ${req.$2} 属历史漂移回归',
        );
      }
    });

    test('无 rating 提交面（评分是访客面动作，坐席端只展示状态）', () async {
      final adapter = useAdapter(200, okEnvelope());
      final api = CsApi();

      await api.claim(orgId, sessionId, expectedVersion: 2);
      await api.close(orgId, sessionId, expectedVersion: 3, reason: '已解决');
      await api.transfer(
        orgId,
        sessionId,
        toIdentityId: 'x',
        expectedVersion: 3,
      );

      for (final req in adapter.requests) {
        expect(
          req.$2.endsWith('/rating'),
          isFalse,
          reason: 'CsApi 不得存在 rating 提交面（访客侧动作）',
        );
      }
    });

    test('全部 CS 动作提交面：无 key_ref / 无任何密文形键 / 无 PATCH 动词', () async {
      final adapter = useAdapter(200, okEnvelope());
      final api = CsApi();

      await api.claim(orgId, sessionId, expectedVersion: 2);
      await api.close(orgId, sessionId, expectedVersion: 3, reason: '已解决');
      await api.transfer(
        orgId,
        sessionId,
        toIdentityId: 'x',
        expectedVersion: 3,
      );

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
      // 已下线）
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
