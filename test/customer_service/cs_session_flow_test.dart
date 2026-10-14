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

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/modules/customer_service/domain/cs_delivery_ack_ledger.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/modules/customer_service/infrastructure/cs_asset_put_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/service/storage.dart';

const kOrgId = '7266418340025468901';
const kWsId = '7266418340025468921';
const kConvId = '7266418340025468950';
const kSessionId = '7266418340025468940';
const kIdentityId = '7266418340025468902';

class _DeliveryAuth extends ChangeNotifier implements AuthSessionReader {
  @override
  AuthSessionScope current = (
    uid: 'synthetic-seat',
    generation: 1,
    transitioning: false,
  );
  void publish(AuthSessionScope scope) {
    current = scope;
    notifyListeners();
  }

  @override
  bool isCurrent(AuthSessionScope captured) => captured == current;
}

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
  Future<ResponseBody>? heldAck;
  final ackStarted = Completer<void>();

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
    if (options.uri.path.endsWith('/ack') && heldAck != null) {
      if (!ackStarted.isCompleted) ackStarted.complete();
      return heldAck!;
    }
    final (status, body) = _match(options.uri.toString());
    if (status == 200 && options.uri.path.endsWith('/content')) {
      final bytes = utf8.encode(body['payload'] as String);
      return ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          'x-asset-id': [options.uri.path.split('/').reversed.elementAt(1)],
          'x-asset-sha256': [sha256.convert(bytes).toString()],
          'content-length': ['${bytes.length}'],
          'content-type': ['application/octet-stream'],
        },
      );
    }
    final payload = body['payload'];
    final response = options.method == 'PUT' && payload is Map
        ? {
            'code': 0,
            'payload': {...payload, 'status': 'pending_confirm'},
          }
        : body;
    return ResponseBody.fromString(
      jsonEncode(response),
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
  List<Map<String, dynamic>>? assets,
}) => {
  'id': id,
  'conversation_id': '7266418340025468950',
  'organization_id': '7266418340025468901',
  'sender_type': senderType,
  'sender_contact_id': senderType == 'contact' ? contactId : null,
  'sender_business_identity_id': senderType == 'business_identity'
      ? identityId
      : null,
  'body': content,
  // CSX-01 冻结投影：纯文本 assets=[]（缺省）；附件消息逐资产行五键白名单。
  'assets': assets ?? <Map<String, dynamic>>[],
};

CsSessionFlow newFlow({
  required HttpClientAdapter adapter,
  String conversationId = '7266418340025468950',
  String workspaceId = '7266418340025468921',
  EnterpriseStore? store,
  void Function()? onChanged,
  CsDeliveryAckLedger? deliveryLedger,
  AuthSessionScope? deliveryAuthScope,
  bool Function()? scopeCurrent,
}) {
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = null);
  return CsSessionFlow(
    deliveryLedger: deliveryLedger,
    deliveryAuthScope: deliveryAuthScope,
    scopeCurrent: scopeCurrent,
    orgId: '7266418340025468901',
    sessionId: '7266418340025468940',
    identityId: '7266418340025468902',
    conversationId: conversationId,
    workspaceId: workspaceId,
    contactMaskedName: '张**',
    store: store ?? EnterpriseMemoryStore(),
    onChanged: onChanged,
    csApi: CsApi(
      assetApiFactory: () =>
          EnterpriseApi()..dio.options.baseUrl = 'https://member.invalid',
      putTransportFactory: () => CsAssetPutTransport(adapter: adapter),
    ),
  );
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '7266418340025468999');
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'readAll') return <String, String>{};
            if (call.method == 'read' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              return token;
            }
            return null;
          },
        );
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

  group('CSX-01 历史附件投影恢复（assets 五键白名单）', () {
    test(
      '历史行 assets 投影解析进 messageAssets；纯文本行为空；query 带 org/workspace',
      () async {
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
                      senderType: 'contact',
                      content: '',
                      assets: [
                        {
                          'id': '7266418340025468970',
                          'mime': 'image/png',
                          'size_bytes': 4096,
                          'file_name': '订单截图.png',
                          'status': 'active',
                        },
                      ],
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
        // 纯文本：无附件投影行。
        expect(flow.messageAssets['7266418340025468961'], isNull);
        // 附件消息：五键投影逐项恢复（渲染面据此分型图片/文件）。
        final assets = flow.messageAssets['7266418340025468962']!;
        expect(assets, hasLength(1));
        expect(assets.single.id, '7266418340025468970');
        expect(assets.single.mime, 'image/png');
        expect(assets.single.sizeBytes, 4096);
        expect(assets.single.fileName, '订单截图.png');
        expect(assets.single.isImage, isTrue);
        // 消息 GET 携带冻结 query（organization_id / workspace_id）。
        final get = adapter.requests.firstWhere(
          (r) => r.$1 == 'GET' && r.$2.contains('/conversations/'),
        );
        expect(get.$4['organization_id'], kOrgId);
        expect(get.$4['workspace_id'], kWsId);
      },
    );

    test('workspace 种子为空：经 seat-contexts 权威解析后带上 query（一次）', () async {
      var seatContextCalls = 0;
      final adapter = _RouteAdapter([
        (
          '/seat-contexts',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'contexts': [
                    {
                      'organization_id': '7266418340025468901',
                      'organization_name': '示例组织',
                      'workspaces': [
                        {'id': '7266418340025468921', 'name': '默认工作区'},
                      ],
                      'business_identity_id': '7266418340025468902',
                      'seat_enabled': true,
                    },
                  ],
                },
              },
            ),
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
                ],
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter, workspaceId: '');

      await flow.loadIncremental();
      expect(flow.workspaceId, kWsId, reason: 'seat-contexts 权威补齐');
      final gets = adapter.requests
          .where((r) => r.$1 == 'GET' && r.$2.contains('/conversations/'))
          .toList();
      expect(gets.single.$4['workspace_id'], kWsId);

      // 解析每 flow 实例只做一次：再拉不重复打 seat-contexts。
      seatContextCalls = adapter.requests
          .where((r) => r.$2.contains('/seat-contexts'))
          .length;
      await flow.loadIncremental();
      final after = adapter.requests
          .where((r) => r.$2.contains('/seat-contexts'))
          .length;
      expect(after, seatContextCalls, reason: 'workspace 解析结果已缓存');
    });
  });

  group('CSM-02 delivery ACK 不删真源', () {
    test('入站未投递消息：ACK 逐条发出；本地只置标记，消息仍在列表与 store', () async {
      final auth = _DeliveryAuth();
      final ledger = CsDeliveryAckLedger.forAuth(auth);
      addTearDown(() {
        ledger.dispose();
        auth.dispose();
      });
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
      final flow = newFlow(
        adapter: adapter,
        store: store,
        deliveryLedger: ledger,
        deliveryAuthScope: auth.current,
      );

      await flow.loadIncremental();

      // ACK 已发（EB ack 路径）；recipient_ref 恒为 identity: 前缀
      //（APP-M02-A01：服务端唯一合法形状，`seat:` 前缀=后端 400 契约）
      final acks = adapter.requests
          .where((r) => r.$2.contains('/ack'))
          .toList();
      expect(acks, hasLength(1));
      final ackBody = Map<String, dynamic>.from(acks.single.$3 as Map);
      expect(ackBody['recipient_ref'], 'identity:7266418340025468902');

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

      await flow.loadLatest();
      await flow.refreshLoadedHistory();
      await flow.loadIncremental();
      expect(
        adapter.requests.where((r) => r.$2.contains('/ack')),
        hasLength(1),
      );
      expect(flow.messages.single.delivered, isTrue);
      expect((await store.messages(kOrgId, kConvId)).single.delivered, isTrue);
      flow.dispose();
      final reopened = newFlow(
        adapter: adapter,
        store: EnterpriseMemoryStore(),
        deliveryLedger: ledger,
        deliveryAuthScope: auth.current,
      );
      addTearDown(reopened.dispose);
      await reopened.loadLatest();
      expect(
        adapter.requests.where((r) => r.$2.contains('/ack')),
        hasLength(1),
      );
      expect(reopened.messages.single.delivered, isTrue);
    });
  });

  group('delivery ACK partial failure and obsolete scope', () {
    const deliveryScope = '$kOrgId/$kWsId/$kSessionId/$kConvId/$kIdentityId';
    const high = '7266418340025468962', low = '7266418340025468961';
    test(
      'partial ACK failure retains first success across page reentry',
      () async {
        final auth = _DeliveryAuth();
        final ledger = CsDeliveryAckLedger.forAuth(auth);
        addTearDown(() {
          ledger.dispose();
          auth.dispose();
        });
        final adapter = _RouteAdapter([
          (
            '/ack',
            [
              (200, {'code': 0}),
              (500, {'code': 500}),
              (200, {'code': 0}),
            ],
          ),
          (
            '/messages',
            [
              (
                200,
                {
                  'code': 0,
                  'payload': [
                    msgJson(id: high, senderType: 'contact'),
                    msgJson(id: low, senderType: 'contact'),
                  ],
                },
              ),
            ],
          ),
        ]);
        final store = EnterpriseMemoryStore();
        final flow = newFlow(
          adapter: adapter,
          store: store,
          deliveryLedger: ledger,
          deliveryAuthScope: auth.current,
        );
        await flow.loadLatest();
        expect(ledger.contains(auth.current, deliveryScope, high), isTrue);
        expect(ledger.contains(auth.current, deliveryScope, low), isFalse);
        expect(
          flow.messages.singleWhere((m) => m.id == high).delivered,
          isTrue,
        );
        expect(
          flow.messages.singleWhere((m) => m.id == low).delivered,
          isFalse,
        );
        flow.dispose();
        final reopened = newFlow(
          adapter: adapter,
          store: EnterpriseMemoryStore(),
          deliveryLedger: ledger,
          deliveryAuthScope: auth.current,
        );
        addTearDown(reopened.dispose);
        await reopened.loadLatest();
        final acks = adapter.requests
            .where((r) => r.$2.contains('/ack'))
            .toList();
        expect(acks, hasLength(3));
        expect(
          acks.map(
            (r) => Uri.parse(r.$2).path.split('/').reversed.elementAt(1),
          ),
          [high, low, low],
        );
        expect(reopened.messages.every((m) => m.delivered), isTrue);
        expect(ledger.contains(auth.current, deliveryScope, low), isTrue);
      },
    );
    test(
      'five page entries with fifty messages send only fifty ACKs',
      () async {
        final auth = _DeliveryAuth();
        final ledger = CsDeliveryAckLedger.forAuth(auth);
        addTearDown(() {
          ledger.dispose();
          auth.dispose();
        });
        final base = BigInt.parse('7266418340025468961');
        final adapter = _RouteAdapter([
          (
            '/ack',
            [
              (200, {'code': 0}),
            ],
          ),
          (
            '/messages',
            [
              (
                200,
                {
                  'code': 0,
                  'payload': [
                    for (var i = 49; i >= 0; i--)
                      msgJson(
                        id: '${base + BigInt.from(i)}',
                        senderType: 'contact',
                      ),
                  ],
                },
              ),
            ],
          ),
        ]);
        for (var entry = 0; entry < 5; entry++) {
          final store = EnterpriseMemoryStore();
          final flow = newFlow(
            adapter: adapter,
            store: store,
            deliveryLedger: ledger,
            deliveryAuthScope: auth.current,
          );
          try {
            await flow.loadLatest();
            expect(flow.messages, hasLength(50));
            expect(flow.messages.every((m) => m.delivered), isTrue);
            expect(
              (await store.messages(kOrgId, kConvId)).every((m) => m.delivered),
              isTrue,
            );
            expect(
              adapter.requests.where((r) => r.$2.contains('/ack')),
              hasLength(50),
              reason: 'page entry $entry',
            );
          } finally {
            flow.dispose();
          }
        }
        final ids = adapter.requests
            .where((r) => r.$2.contains('/ack'))
            .map((r) => Uri.parse(r.$2).path.split('/').reversed.elementAt(1))
            .toSet();
        expect(ids, hasLength(50));
      },
    );

    for (final change in ['dispose', 'revoke', 'auth-transition']) {
      test(
        'late ACK success after $change never restores delivery authority',
        () async {
          final auth = _DeliveryAuth();
          final captured = auth.current;
          final ledger = CsDeliveryAckLedger.forAuth(auth);
          addTearDown(() {
            ledger.dispose();
            auth.dispose();
          });
          final pending = Completer<ResponseBody>();
          final adapter = _RouteAdapter([
            (
              '/messages',
              [
                (
                  200,
                  {
                    'code': 0,
                    'payload': [msgJson(id: low, senderType: 'contact')],
                  },
                ),
              ],
            ),
          ])..heldAck = pending.future;
          var current = true;
          final store = EnterpriseMemoryStore();
          final flow = newFlow(
            adapter: adapter,
            store: store,
            deliveryLedger: ledger,
            deliveryAuthScope: captured,
            scopeCurrent: () => current,
          );
          addTearDown(flow.dispose);
          final loading = flow.loadLatest();
          await adapter.ackStarted.future;
          switch (change) {
            case 'dispose':
              flow.dispose();
            case 'revoke':
              flow.invalidateReadScope();
            case 'auth-transition':
              current = false;
              auth.publish((
                uid: captured.uid,
                generation: captured.generation + 1,
                transitioning: true,
              ));
          }
          pending.complete(
            ResponseBody.fromString(
              jsonEncode({'code': 0}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            ),
          );
          await loading;
          expect(ledger.contains(captured, deliveryScope, low), isFalse);
          expect(
            (await store.messages(kOrgId, kConvId)).single.delivered,
            isFalse,
          );
          expect(flow.messages.any((m) => m.delivered), isFalse);
          if (change == 'revoke') {
            expect(flow.messages, isEmpty);
            expect(flow.readRevoked, isTrue);
          }
          expect(
            adapter.requests.where((r) => r.$2.contains('/ack')),
            hasLength(1),
          );
        },
      );
    }
  });

  group('CSM-02 附件三步（presign→PUT→confirm）不泄露存储 URL', () {
    final demoBytes = Uint8List.fromList(utf8.encode('demo'));
    final demoHash = sha256.convert(demoBytes).toString();

    /// CSX-01 冻结 presign 响应（嵌套 upload.url；企业面 url 可缺省）。
    Map<String, dynamic> presignView({String? uploadUrl}) => {
      'asset_id': '7266418340025468970',
      'upload_ref': 'opaque-upload-ref',
      'object_hash': demoHash,
      'mime': 'text/plain',
      'size_bytes': demoBytes.length,
      'file_name': 'a.txt',
      'expires_at': 1789000100,
      'upload': {
        'method': 'PUT',
        'token': 'opaque-upload-ref',
        'expires_at': 1789000100,
        'adapter': 'local_private_object_store',
        'rule': 'opaque_token_no_url_no_object_key',
        'url': ?uploadUrl,
      },
    };

    test('顺序正确；presign 请求体冻结契约（object_hash=SHA-256）；upload_url 不落 store', () async {
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
                'payload': presignView(
                  uploadUrl:
                      'https://member.invalid/api/v1/enterprise/organizations/$kOrgId/assets/presign?workspace_id=$kWsId&upload_ref=opaque-upload-ref',
                ),
              },
            ),
          ],
        ),
        (
          'assets/confirm',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'asset_id': '7266418340025468970',
                  'status': 'active',
                  'object_hash': demoHash,
                  'conversation_id': kConvId,
                  'mime': 'text/plain',
                  'size_bytes': 4,
                  'file_name': 'a.txt',
                },
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter, store: store);

      final assetId = await flow.uploadAsset(
        mime: 'text/plain',
        bytes: demoBytes,
        fileName: 'a.txt',
      );

      expect(assetId, '7266418340025468970');
      final uris = adapter.requests.map((r) => r.$2).toList();
      expect(
        adapter.requests.where(
          (r) => r.$1 == 'POST' && r.$2.contains('/assets/presign'),
        ),
        hasLength(1),
      );
      expect(
        adapter.requests.where(
          (r) => r.$1 == 'PUT' && r.$2.contains('member.invalid'),
        ),
        hasLength(1),
        reason: '裸 PUT 直传一次（嵌套 upload.url 目标）',
      );
      expect(uris.where((p) => p.contains('/assets/confirm')), hasLength(1));
      final putIndex = adapter.requests.indexWhere((r) => r.$1 == 'PUT');
      expect(
        putIndex,
        greaterThan(uris.indexWhere((p) => p.contains('/presign'))),
      );
      expect(
        putIndex,
        lessThan(uris.indexWhere((p) => p.contains('/confirm'))),
      );

      // presign 请求体冻结契约：{workspace_id, conversation_id, mime,
      // size_bytes, object_hash, file_name}；object_hash 是字节 SHA-256。
      final presignReq = adapter.requests.firstWhere(
        (r) => r.$2.contains('/assets/presign'),
      );
      final presignBody = Map<String, dynamic>.from(presignReq.$3 as Map);
      expect(presignBody.keys.toSet(), {
        'workspace_id',
        'conversation_id',
        'mime',
        'size_bytes',
        'object_hash',
        'file_name',
      });
      expect(presignBody['workspace_id'], kWsId);
      expect(presignBody['conversation_id'], kConvId);
      expect(presignBody['object_hash'], demoHash);
      // confirm 请求体：upload_ref（非 asset_id）。
      final confirmReq = adapter.requests.firstWhere(
        (r) => r.$2.contains('/assets/confirm'),
      );
      final confirmBody = Map<String, dynamic>.from(confirmReq.$3 as Map);
      expect(confirmBody.keys.toSet(), {'workspace_id', 'upload_ref'});
      expect(confirmBody['upload_ref'], 'opaque-upload-ref');

      // EB-D06：presigned URL / object key 不得落 store（store 只存键以
      // enterprise_ 前缀的元信息）
      expect(
        store.debugKeys().any(
          (k) =>
              k.contains('upload') ||
              k.contains('upload.example') ||
              k.contains('ref='),
        ),
        isFalse,
      );
    });

    test(
      'fail-closed：presign 无 upload.url（企业面合同形状）→ 抛出且不 PUT/不 confirm/不发消息',
      () async {
        final adapter = _RouteAdapter([
          (
            'assets/presign',
            [
              (200, {'code': 0, 'msg': 'success', 'payload': presignView()}),
            ],
          ),
        ]);
        final flow = newFlow(adapter: adapter);

        Object? caught;
        try {
          await flow.uploadAsset(
            mime: 'text/plain',
            bytes: demoBytes,
            fileName: 'a.txt',
          );
          fail('无 PUT 目标必须 fail-closed 抛出（绝不自造端点）');
        } on Object catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(
          adapter.requests.where((r) => !r.$2.contains('/assets/presign')),
          isEmpty,
          reason: '只发 presign：不 PUT、不 confirm',
        );
        expect(
          adapter.requests.where((r) => r.$2.contains('/messages')),
          isEmpty,
          reason: '§3.7：失败不得产生文件名文本附件',
        );
        expect(flow.messages, isEmpty);
      },
    );
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
          '/sessions/7266418340025468940',
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
          '/sessions/7266418340025468940',
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
      expect(flow.lastFailureKind, CsSeatFailureKind.suspended);

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
      expect(flow.lastFailureKind, CsSeatFailureKind.offboarding);
    });

    test('A05：普通 409（CAS）分类为 conflict，可刷新重试，与 offboarding 分离', () async {
      final adapter = _RouteAdapter([
        (
          '/close',
          [
            (409, {'code': 409, 'msg': '{cas_mismatch, ...}'}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);
      flow.detail = const CsSessionDetail(
        sessionId: kSessionId,
        status: 'active',
        version: 3,
      );

      final kind = await flow.closeSession();
      expect(kind, CsSeatFailureKind.conflict);
      expect(flow.lastFailureKind, CsSeatFailureKind.conflict);
      // 冲突不降级：仍可写（刷新真实状态后可重试）。
      expect(flow.machine.canSend, isTrue);
    });
  });

  group('APP-M02-A03 附件消息原子绑定（asset_ids）', () {
    test('发送带 asset_ids；失败重试复用同一 client_msg_id 与同一组 asset_ids', () async {
      final sentJson = msgJson(
        id: '7266418340025468971',
        senderType: 'business_identity',
        content: '',
      );
      final adapter = _RouteAdapter([
        (
          'conversations/$kConvId/messages',
          [
            (500, {'code': 500, 'msg': 'boom'}),
            (200, {'code': 0, 'msg': 'success', 'payload': sentJson}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);

      final first = await flow.send('', assetIds: ['7266418340025468970']);
      expect(first, isFalse);
      expect(flow.pendingClientMsgId, isNotNull);
      expect(flow.pendingAssetIds, ['7266418340025468970']);
      final id1 = flow.pendingClientMsgId;

      final second = await flow.send('', assetIds: ['7266418340025468970']);
      expect(second, isTrue);
      expect(flow.pendingClientMsgId, isNull);
      expect(flow.pendingAssetIds, isNull, reason: '确认后幂等键清空');

      final sends = adapter.requests
          .where((r) => r.$1 == 'POST' && r.$2.contains('/messages'))
          .toList();
      expect(sends, hasLength(2));
      final body1 = Map<String, dynamic>.from(sends[0].$3 as Map);
      final body2 = Map<String, dynamic>.from(sends[1].$3 as Map);
      expect(body1['client_msg_id'], id1);
      expect(body2['client_msg_id'], id1, reason: 'A03 同键同附件 = 同一 message');
      expect(body1['asset_ids'], ['7266418340025468970']);
      expect(body2['asset_ids'], ['7266418340025468970']);
      // 本地不伪成功：确认前消息不进列表；确认后带附件投影。
      expect(flow.messages.single.id, '7266418340025468971');
      expect(flow.messageAssets['7266418340025468971'], isNotNull);
    });

    test('上传失败不产生文件名文本附件：不发送任何消息请求', () async {
      final adapter = _RouteAdapter([
        (
          'assets/presign',
          [
            (500, {'code': 500, 'msg': 'presign boom'}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);

      Object? caught;
      try {
        await flow.uploadAsset(
          mime: 'text/plain',
          bytes: Uint8List.fromList(utf8.encode('demo')),
          fileName: 'a.txt',
        );
        fail('presign 失败必须抛出（不伪成功）');
      } on Object catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(
        adapter.requests.where((r) => r.$2.contains('/messages')),
        isEmpty,
        reason: '§3.7：失败不得产生文件名文本附件',
      );
      expect(flow.messages, isEmpty);
    });

    test('空正文且无附件不发送；关闭后附件查看仍经授权代理（读面）', () async {
      final adapter = _RouteAdapter([
        (
          '/close',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
        (
          'assets/7266418340025468970/content',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': 'file-bytes'}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);
      flow.detail = const CsSessionDetail(
        sessionId: kSessionId,
        status: 'active',
        version: 3,
      );

      expect(await flow.send('   '), isFalse, reason: '空正文+无附件不发送');
      final before = adapter.requests.length;
      expect(await flow.send('   '), isFalse);
      expect(adapter.requests.length, before, reason: '无请求发出');

      // close 成功 → 写入口全禁（send/attach/transfer/close），读面保留。
      final kind = await flow.closeSession();
      expect(kind, isNull);
      expect(flow.machine.canSend, isFalse);
      expect(flow.machine.canDownload, isTrue);
      final viewed = await flow.fetchAssetBytes('7266418340025468970');
      expect(viewed, isNotNull, reason: 'closed 只读态附件查看仍走授权代理');
      final contentReq = adapter.requests.firstWhere(
        (r) => r.$2.contains('assets/7266418340025468970/content'),
      );
      expect(
        Uri.parse(contentReq.$2).queryParameters['workspace_id'],
        kWsId,
        reason: 'PR-W2-C01：content 门查询串必带 workspace_id（缺即 422）',
      );
    });

    test('附件内容代理：workspace 种子为空时先经 seat-contexts 权威解析', () async {
      final adapter = _RouteAdapter([
        (
          '/seat-contexts',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'contexts': [
                    {
                      'organization_id': '7266418340025468901',
                      'organization_name': '示例组织',
                      'workspaces': [
                        {'id': '7266418340025468921', 'name': '默认工作区'},
                      ],
                      'business_identity_id': '7266418340025468902',
                      'seat_enabled': true,
                    },
                  ],
                },
              },
            ),
          ],
        ),
        (
          'assets/7266418340025468970/content',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': 'file-bytes'}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter, workspaceId: '');
      flow.detail = const CsSessionDetail(sessionId: kSessionId, version: 3);

      final viewed = await flow.fetchAssetBytes('7266418340025468970');
      expect(viewed, isNotNull);
      expect(
        adapter.requests.where((r) => r.$2.contains('/seat-contexts')).length,
        1,
        reason: '空种子先权威解析（每 flow 实例只解析一次）',
      );
      final contentReq = adapter.requests.firstWhere(
        (r) => r.$2.contains('assets/7266418340025468970/content'),
      );
      expect(
        Uri.parse(contentReq.$2).queryParameters['workspace_id'],
        kWsId,
        reason: '解析结果必须进 content 查询串，不得裸发旧形状',
      );
    });
  });

  group('APP-M02-A04 转接生命周期', () {
    test('transfer 成功 → 旧坐席立即只读（transferredAway）', () async {
      final adapter = _RouteAdapter([
        (
          '/transfer',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);
      flow.detail = const CsSessionDetail(
        sessionId: kSessionId,
        status: 'active',
        version: 3,
      );

      final kind = await flow.transferTo('7266418340025468943');
      expect(kind, isNull);
      expect(flow.machine.phase, CsSeatSessionPhase.transferredAway);
      expect(flow.machine.canSend, isFalse);
      expect(flow.machine.shouldPoll, isFalse);
      expect(flow.machine.canDownload, isFalse, reason: '经办权已离开');

      final before = adapter.requests.length;
      final sent = await flow.send('还想回复');
      expect(sent, isFalse);
      expect(adapter.requests.length, before, reason: '转接后写入口清空');
      expect(await flow.fetchAssetBytes('a1'), isNull);
    });

    test('服务端回显经办人非当前坐席 → transferredAway；本值不被回显覆盖', () async {
      final adapter = _RouteAdapter([
        (
          '/sessions/$kSessionId',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': {
                  'session_id': 7266418340025468940,
                  'status': 'active',
                  'version': 7,
                  'conversation_id': 7266418340025468950,
                  'business_identity_id': 7266418340025468999,
                },
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);

      await flow.refreshSessionState();
      expect(flow.machine.phase, CsSeatSessionPhase.transferredAway);
      expect(flow.identityId, kIdentityId, reason: '本人身份不被他人回显覆盖');
      expect(flow.machine.canSend, isFalse);
    });
  });

  group('APP-M02-A02 坐席事件流（SSE 权威刷新）', () {
    Stream<List<int>> sse(List<Map<String, dynamic>> envelopes) => Stream.value(
      utf8.encode(
        envelopes
            .map(
              (e) =>
                  'id: ${e['event_id']}\nevent: ${e['type']}\n'
                  'data: ${jsonEncode(e)}\n\n',
            )
            .join(),
      ),
    );

    Map<String, dynamic> env(
      String id,
      String type, {
      String resourceId = '',
    }) => {
      'event_id': id,
      'type': type,
      'organization_id': kOrgId,
      'workspace_id': kWsId,
      'resource_type': 'message',
      'resource_id': resourceId.isNotEmpty
          ? resourceId
          : type == 'resync.required'
          ? ''
          : type == 'message.appended'
          ? '7266418340025468961'
          : kSessionId,
      'resource_version': 1,
      'occurred_at': '2026-09-20T05:14:47Z',
      'reason': 'created',
    };

    test('message.appended → 增量权威拉取：访客新消息自动出现', () async {
      final adapter = _RouteAdapter([
        (
          '/ack',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
        (
          'conversations/$kConvId/messages',
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
      var updates = 0;
      final flow = newFlow(adapter: adapter, onChanged: () => updates++);
      expect(flow.messages, isEmpty);

      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener: (
          String orgId,
          String workspaceId, {
          String lastEventId = '',
          String afterId = '',
        }) async => sse([env('7266418340025469001', 'message.appended')]),
      );
      flow.bindEvents(stream);
      // 事件经真实微任务链路触发权威拉取（无轮询）。
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(flow.messages, hasLength(1), reason: '访客新消息自动出现');
      expect(updates, 1, reason: '权威数据同步后必须通知页面重建');
      flow.dispose();
    });

    test('resync.required → 清游标全量权威刷新（下一拉取不带 after_id）', () async {
      final adapter = _RouteAdapter([
        (
          'conversations/$kConvId/messages',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': [
                  msgJson(id: '7266418340025468961', senderType: 'contact'),
                ],
              },
            ),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);
      await flow.loadIncremental();
      expect(flow.cursor, '7266418340025468961');

      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener: (
          String orgId,
          String workspaceId, {
          String lastEventId = '',
          String afterId = '',
        }) async => sse([env('7266418340025469002', 'resync.required')]),
      );
      flow.bindEvents(stream);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // resync 先清空游标再全量重拉（拉取后游标按真源重新推进）——
      // 「全量」由最后一拉不带 after_id 证明。
      final lastGet = adapter.requests.lastWhere(
        (r) => r.$1 == 'GET' && r.$2.contains('/conversations/'),
      );
      expect(lastGet.$4.containsKey('after_id'), isFalse, reason: '全量首拉');
      flow.dispose();
    });

    test('降级后停止消费事件（不再发权威请求）', () async {
      final adapter = _RouteAdapter([
        (
          'conversations/$kConvId/messages',
          [
            (403, {'code': 403, 'msg': 'forbidden'}),
          ],
        ),
      ]);
      final flow = newFlow(adapter: adapter);
      await flow.loadIncremental(poll: true);
      expect(flow.machine.shouldPoll, isFalse);
      final before = adapter.requests.length;

      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener: (
          String orgId,
          String workspaceId, {
          String lastEventId = '',
          String afterId = '',
        }) async => sse([env('7266418340025469003', 'message.appended')]),
      );
      flow.bindEvents(stream);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(adapter.requests.length, before, reason: '降级后事件不触发请求');
      flow.dispose();
    });
  });
}
