/// CSM-02（§12.5.1）— 坐席会话数据流单测（fake HTTP 桩）
///
/// 覆盖：
/// - 发送幂等：失败重试复用同一 client_msg_id；成功后 pending 清空；
/// - after_id 增量：游标推进、追加不重复；
/// - delivery ACK 不删真源：入站消息 ACK 后本地只置标记，消息仍在
///   内存列表与 store（delivery-only 语义）；
/// - 附件三步（presign→PUT→confirm）：顺序正确；upload_url 不落 store
///   （EB-D06：客户端不持久化 presigned URL / object key）；
/// - transfer CAS 冲突恢复：409 → 刷新真实 detail（新 version）；
/// - close 后禁写：canSend=false，send 不再发请求；
/// - 降级：403 → 只读+停后台发送（poll 不再发请求）；
///   offboarding 409 → 只读终态。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';
import 'package:imboy/service/storage.dart';

/// 按路径路由响应的桩：fragment 按**注册顺序**取第一个命中（因此更长的
/// / 更特殊的 fragment 应先注册）；每条路由的响应按序消费，耗尽后停留在
/// 最后一个。未命中 → 200 空 envelope。
class _RouteAdapter implements HttpClientAdapter {
  final List<(String fragment, List<(int, Map<String, dynamic>)> responses)>
  routes;

  final Map<String, int> _cursors = <String, int>{};

  /// 每次请求的 (method, fullUri, data, queryParameters)。
  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

  _RouteAdapter(this.routes);

  (int, Map<String, dynamic>) _match(String path) {
    for (final (fragment, responses) in routes) {
      if (path.contains(fragment)) {
        final i = _cursors.putIfAbsent(fragment, () => 0);
        _cursors[fragment] = (i + 1).clamp(0, responses.length - 1);
        return responses[i];
      }
    }
    return (200, {'code': 0, 'msg': 'success', 'payload': null});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      options.method,
      options.uri.toString(),
      options.data,
      Map<String, dynamic>.from(options.queryParameters),
    ));
    final (status, body) = _match(options.uri.toString());
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

Map<String, dynamic> msgJson({
  required String id,
  required String senderType,
  String contactId = '7266418340025468941',
  String identityId = '7266418340025468902',
  String content = 'hello',
  bool delivered = true,
}) => {
  'id': id,
  'conversation_id': '7266418340025468950',
  'organization_id': '7266418340025468901',
  'sender_type': senderType,
  'sender_contact_id': senderType == 'contact' ? contactId : null,
  'sender_business_identity_id': senderType == 'business_identity'
      ? identityId
      : null,
  'content': content,
  'delivered': delivered,
};

CsSessionFlow newFlow({
  required HttpClientAdapter adapter,
  String conversationId = '7266418340025468950',
  EnterpriseStore? store,
}) {
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = null);
  return CsSessionFlow(
    orgId: '7266418340025468901',
    sessionId: '7266418340025468940',
    identityId: '7266418340025468902',
    conversationId: conversationId,
    contactMaskedName: '张**',
    store: store ?? EnterpriseMemoryStore(),
  );
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('CSM-02 发送幂等（client_msg_id）', () {
    test('失败重试复用同一 id；成功后 pending 清空', () async {
      final sentJson = msgJson(
        id: '7266418340025468963',
        senderType: 'business_identity',
        content: '您好',
      );
      final adapter = _RouteAdapter([
        // 第一次发送 500；之后 200（同 id 重放由服务端幂等裁决）
        (
          'conversations/7266418340025468950/messages',
          [
            (500, {'code': 500, 'msg': 'boom'}),
            (200, {'code': 0, 'msg': 'success', 'payload': sentJson}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);

      final first = await flow.send('您好');
      expect(first, isFalse);
      expect(flow.pendingClientMsgId, isNotNull);
      final id1 = flow.pendingClientMsgId;

      final second = await flow.send('您好');
      expect(second, isTrue, reason: '第二次命中 200 桩');
      expect(flow.pendingClientMsgId, isNull);

      final sends = adapter.requests
          .where((r) => r.$1 == 'POST' && r.$2.contains('/messages'))
          .toList();
      expect(sends, hasLength(2));
      final body1 = Map<String, dynamic>.from(sends[0].$3 as Map);
      final body2 = Map<String, dynamic>.from(sends[1].$3 as Map);
      expect(body1['client_msg_id'], id1);
      expect(body2['client_msg_id'], id1, reason: '重试必须复用同一幂等键');
    });
  });

  group('CSM-02 after_id 增量', () {
    test('游标推进；追加去重', () async {
      final adapter = _RouteAdapter([
        (
          '/ack',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
        (
          '/conversations/7266418340025468950/messages',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': [
                  msgJson(id: '7266418340025468961', senderType: 'contact'),
                  msgJson(
                    id: '7266418340025468962',
                    senderType: 'business_identity',
                  ),
                ],
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);

      await flow.loadIncremental();
      expect(flow.messages, hasLength(2));
      expect(flow.cursor, '7266418340025468962');

      // 同一批再拉（桩恒返同一批）：按 id 去重不得重复
      await flow.loadIncremental();
      expect(flow.messages, hasLength(2), reason: '追加去重');
      // 增量请求必须携带 after_id 游标
      final lastGet = adapter.requests.reversed.firstWhere(
        (r) => r.$1 == 'GET' && r.$2.contains('/conversations/'),
      );
      expect(lastGet.$4['after_id'], '7266418340025468962');
    });
  });

  group('CSM-02 delivery ACK 不删真源', () {
    test('入站未投递消息：ACK 逐条发出；本地只置标记，消息仍在列表与 store', () async {
      final store = EnterpriseMemoryStore();
      final adapter = _RouteAdapter([
        (
          '/ack',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
        (
          '/conversations/7266418340025468950/messages',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': [
                  msgJson(
                    id: '7266418340025468961',
                    senderType: 'contact',
                    delivered: false,
                  ),
                ],
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter, store: store);

      await flow.loadIncremental();

      // ACK 已发（EB ack 路径）
      final acks = adapter.requests
          .where((r) => r.$2.contains('/ack'))
          .toList();
      expect(acks, hasLength(1));
      final ackBody = Map<String, dynamic>.from(acks.single.$3 as Map);
      expect(ackBody['recipient_ref'], 'seat:7266418340025468902');

      // 本地：标记置位但消息保留（delivery-only，不删真源）
      expect(flow.messages, hasLength(1));
      expect(flow.messages.single.delivered, isTrue);

      // store：键仍在、副本已置标记
      final stored = await store.messages(
        '7266418340025468901',
        '7266418340025468950',
      );
      expect(stored, hasLength(1));
      expect(stored.single.delivered, isTrue);
    });
  });

  group('CSM-02 附件三步（presign→PUT→confirm）不泄露存储 URL', () {
    test('顺序正确；upload_url / object key 不落 store', () async {
      final store = EnterpriseMemoryStore();
      final adapter = _RouteAdapter([
        (
          'assets/presign',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'asset_id': '7266418340025468970',
                  'upload_url': 'https://s3.example.internal/secret?sig=xyz',
                  'expires_at': '1789000000000',
                },
              },
            ),
          ],
        ),
        (
          'assets/confirm',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter, store: store);

      final assetId = await flow.uploadAsset(
        fileName: 'a.txt',
        mime: 'text/plain',
        size: 4,
        byteStream: Stream<List<int>>.value(utf8.encode('demo')),
      );

      expect(assetId, '7266418340025468970');
      final uris = adapter.requests.map((r) => r.$2).toList();
      expect(uris.where((p) => p.contains('/assets/presign')), hasLength(1));
      expect(
        uris.where((p) => p.contains('s3.example.internal')),
        hasLength(1),
        reason: 'PUT 直传一次',
      );
      expect(uris.where((p) => p.contains('/assets/confirm')), hasLength(1));
      final putIndex = uris.indexWhere((p) => p.contains('s3.example'));
      expect(
        putIndex,
        greaterThan(uris.indexWhere((p) => p.contains('/presign'))),
      );
      expect(
        putIndex,
        lessThan(uris.indexWhere((p) => p.contains('/confirm'))),
      );

      // EB-D06：presigned URL / object key 不得落 store（store 只存键以
      // enterprise_ 前缀的元信息）
      expect(
        store.debugKeys().any(
          (k) =>
              k.contains('upload') ||
              k.contains('s3.example') ||
              k.contains('sig='),
        ),
        isFalse,
      );
    });
  });

  group('CSM-02 transfer CAS 冲突恢复', () {
    test('409 → 返回 conflict 并刷新真实 detail（version 更新）', () async {
      final adapter = _RouteAdapter([
        // 顺序敏感：'/transfer' 必须先于 detail fragment（前缀包含）
        (
          '/transfer',
          [
            (409, {'code': 409, 'msg': '{cas_mismatch, ...}'}),
          ],
        ),
        (
          '/cs/sessions/7266418340025468940',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'session_id': 7266418340025468940,
                  'status': 'active',
                  'version': 5,
                  'conversation_id': 7266418340025468950,
                },
              },
            ),
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'session_id': 7266418340025468940,
                  'status': 'active',
                  'version': 6,
                  'conversation_id': 7266418340025468950,
                },
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);
      await flow.refreshSessionState();
      expect(flow.detail?.version, 5);

      final kind = await flow.transferTo('7266418340025468943');
      expect(kind, CsSeatFailureKind.conflict);
      // 冲突后已刷新真实状态（版本 5 → 6）
      expect(flow.detail?.version, 6);
    });
  });

  group('CSM-02 close 后禁写', () {
    test('close 成功 → canSend=false；send 不再发请求', () async {
      final adapter = _RouteAdapter([
        (
          '/close',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
        (
          '/cs/sessions/7266418340025468940',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'session_id': 7266418340025468940,
                  'status': 'active',
                  'version': 5,
                },
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);
      await flow.refreshSessionState();

      final kind = await flow.closeSession(reason: '已解决');
      expect(kind, isNull);
      expect(flow.machine.canSend, isFalse);
      expect(flow.machine.phase, CsSeatSessionPhase.closed);

      final before = adapter.requests.length;
      final sent = await flow.send('还想说一句');
      expect(sent, isFalse, reason: '关闭后输入禁用');
      expect(adapter.requests.length, before, reason: '禁写后不得发请求');
    });
  });

  group('CSM-02 降级（suspend / offboarding）', () {
    test('403 → 清写入口 + 停后台发送；poll 拉取不再发请求', () async {
      final adapter = _RouteAdapter([
        (
          'conversations/7266418340025468950/messages',
          [
            (403, {'code': 403, 'msg': 'forbidden'}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);

      await flow.loadIncremental(poll: true);
      expect(flow.machine.phase, CsSeatSessionPhase.readOnlySuspended);
      expect(flow.machine.canSend, isFalse);
      expect(flow.machine.shouldPoll, isFalse);

      final before = adapter.requests.length;
      await flow.loadIncremental(poll: true);
      expect(adapter.requests.length, before, reason: '降级后停后台发送/轮询');
    });

    test('offboarding 409 → 只读终态，不可恢复', () async {
      final adapter = _RouteAdapter([
        (
          'conversations/7266418340025468950/messages',
          [
            (409, {'code': 409, 'msg': 'offboarding_required'}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);

      await flow.loadIncremental(poll: true);
      expect(flow.machine.phase, CsSeatSessionPhase.offboardingRequired);
      expect(flow.machine.canSend, isFalse);
      expect(flow.machine.restoreFromSuspension(), isFalse);
    });
  });
}
