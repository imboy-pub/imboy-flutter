/// CSM-03（§12.5.1 / §12.7 A05）— suspend/offboarding 降级验收单测
///
/// 五态矩阵（后端权威态 → HTTP 表现 → 客户端行为）：
///
/// | 后端态                    | HTTP         | 客户端行为                  |
/// |--------------------------|--------------|----------------------------|
/// | seat disabled            | 403          | readOnlySuspended + 停 poll |
/// | member suspended         | 403          | readOnlySuspended + 停 poll |
/// | assignment ended         | 403          | readOnlySuspended + 停 poll |
/// | member removed           | 403          | readOnlySuspended + 停 poll |
/// | offboarding frozen       | 409 offboard | offboardingRequired（终态） |
/// | offboarding transferred  | 409 offboard | offboardingRequired（终态） |
///
/// 每态统一断言（任务原文口径）：旧 JWT/旧缓存不能继续 claim/send/
/// download——403/409 后 canSend=false（清写入口）、shouldPoll=false
/// （停 poll）、后续同类操作**零请求**、explainKey 对应只读态。
///
/// A→B rebind（fake/桩级）：transfer 后 B 以同一 (org, session,
/// conversation) 继续经办——资源 ID 不变、消息 count 不变、历史
/// sender/actor 不重写。
///
/// 个人数据边界：全链路操作后本地缓存键全部 `enterprise_` 前缀
/// （APP-A02 隔离契约）；customer_service 模块源码不含任何个人域
/// store/repo 的 import（静态扫描）。
library;

import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart'
    show EnterpriseSenderType;
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart'
    show CsApiException;
import 'package:imboy/service/storage.dart';

const orgId = '7266418340025468901';
const sessionId = '7266418340025468940';
const conversationId = '7266418340025468950';
const seatA = '7266418340025468902';
const seatB = '7266418340025468903';

/// 记录请求 + 按注册顺序返回响应的桩（fragment 首个命中；响应按序消费，
/// 耗尽停留最后一个；未命中 → 200 空 envelope）。
class _SeqAdapter implements HttpClientAdapter {
  final List<(String fragment, List<(int, Map<String, dynamic>)>)> routes;
  final Map<String, int> _cursor = {};
  final List<(String, String)> requests = [];

  _SeqAdapter(this.routes);

  (int, Map<String, dynamic>) _match(String path) {
    for (final (fragment, responses) in routes) {
      if (path.contains(fragment)) {
        final i = _cursor.putIfAbsent(fragment, () => 0);
        _cursor[fragment] = (i + 1).clamp(0, responses.length - 1);
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
    requests.add((options.method, options.uri.path));
    final (status, body) = _match(options.uri.path);
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

Map<String, dynamic> _detailBody(
  String status,
  int v, {
  String assignee = seatA,
}) => {
  'code': 0,
  'msg': 'success',
  'payload': {
    'session_id': sessionId,
    'organization_id': orgId,
    'conversation_id': conversationId,
    'status': status,
    'version': v,
    'business_identity_id': assignee,
  },
};

CsSessionFlow newFlow(EnterpriseStore store, HttpClientAdapter adapter) {
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = null);
  return CsSessionFlow(
    orgId: orgId,
    sessionId: sessionId,
    identityId: seatA,
    conversationId: conversationId,
    contactMaskedName: '张**',
    store: store,
  );
}

/// 已降级断言：清写入口 + 停 poll。
void expectDegraded(CsSessionFlow flow, CsSeatSessionPhase phase) {
  expect(flow.machine.phase, phase);
  expect(flow.machine.canSend, isFalse, reason: '清写入口');
  expect(flow.machine.shouldPoll, isFalse, reason: '停后台发送/轮询');
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('CSM-03 五态降级矩阵（旧 JWT 不能继续 claim/send/download）', () {
    for (final (name, phase) in [
      ('seat disabled → 403', CsSeatSessionPhase.readOnlySuspended),
      ('member suspended → 403', CsSeatSessionPhase.readOnlySuspended),
      ('assignment ended → 403', CsSeatSessionPhase.readOnlySuspended),
      ('member removed → 403', CsSeatSessionPhase.readOnlySuspended),
    ]) {
      test('detail 请求面：$name（explainKey 只读态）', () async {
        final store = EnterpriseMemoryStore();
        final adapter = _SeqAdapter([
          (
            '/sessions/$sessionId',
            [
              (403, {'code': 403, 'msg': 'forbidden'}),
            ],
          ),
        ]);
        final flow = newFlow(store, adapter);

        await flow.refreshSessionState();
        expectDegraded(flow, phase);
        expect(flow.machine.explainKey, phase.wireName);

        // 旧 JWT 不能继续：send / download 零请求
        final before = adapter.requests.length;
        expect(await flow.send('还想发'), isFalse);
        expect(await flow.viewAsset('7266418340025468970'), isNull);
        expect(adapter.requests.length, before, reason: '降级后零请求');
      });
    }

    test('发送面：offboarding frozen/transferring → 409 终态 + 停 poll', () async {
      final store = EnterpriseMemoryStore();
      final adapter = _SeqAdapter([
        (
          '/conversations/$conversationId/messages',
          [
            (409, {'code': 409, 'msg': 'offboarding_required'}),
          ],
        ),
      ]);
      final flow = newFlow(store, adapter);

      await flow.loadIncremental(poll: true);
      expectDegraded(flow, CsSeatSessionPhase.offboardingRequired);
      expect(flow.machine.explainKey, 'offboardingRequired');

      // 终态：suspend 恢复口无效；后续 send/download/poll 零请求
      expect(flow.machine.restoreFromSuspension(), isFalse);
      final before = adapter.requests.length;
      expect(await flow.send('还想发'), isFalse);
      expect(await flow.viewAsset('7266418340025468970'), isNull);
      expect(await flow.loadIncremental(poll: true), isEmpty);
      expect(adapter.requests.length, before, reason: '降级后零请求');
    });

    test('download 面：content 代理 403 → 降级且后续下载零请求', () async {
      final store = EnterpriseMemoryStore();
      final adapter = _SeqAdapter([
        (
          'assets/7266418340025468970/content',
          [
            (403, {'code': 403, 'msg': 'forbidden'}),
          ],
        ),
      ]);
      final flow = newFlow(store, adapter);

      final preview = await flow.viewAsset('7266418340025468970');
      expect(preview, isNull);
      expectDegraded(flow, CsSeatSessionPhase.readOnlySuspended);

      final before = adapter.requests.length;
      expect(await flow.viewAsset('7266418340025468970'), isNull);
      expect(await flow.send('x'), isFalse);
      expect(adapter.requests.length, before);
    });

    test('claim 面：403 → 清写入口 + 停 poll（工作台侧旧 JWT 不可再接单）', () async {
      final store = EnterpriseMemoryStore();
      final adapter = _SeqAdapter([]);
      final flow = newFlow(store, adapter);

      final kind = flow.applyFailure(const CsApiException(403, 'forbidden'));
      expect(kind, CsSeatFailureKind.suspended);
      expect(flow.machine.canSend, isFalse);
      expect(flow.machine.shouldPoll, isFalse);
      expect(flow.machine.explainKey, 'readOnlySuspended');
      expect(adapter.requests, isEmpty, reason: '拒绝不产生任何网络请求');
    });

    test('offboarding 面：409 offboarding_required → 只读终态（claim 口径）', () async {
      final store = EnterpriseMemoryStore();
      final adapter = _SeqAdapter([]);
      final flow = newFlow(store, adapter);

      final kind = flow.applyFailure(
        const CsApiException(409, 'offboarding_required'),
      );
      expect(kind, CsSeatFailureKind.offboarding);
      expectDegraded(flow, CsSeatSessionPhase.offboardingRequired);
      expect(flow.machine.restoreFromSuspension(), isFalse);
      expect(adapter.requests, isEmpty);
    });
  });

  group('CSM-03 A→B rebind（资源不变、历史不重写）', () {
    test('B 继续同 session/conversation：ID 不变、count 不变、sender 不重写', () async {
      final store = EnterpriseMemoryStore();
      final history = [
        {
          'id': '7266418340025468961',
          'conversation_id': conversationId,
          'organization_id': orgId,
          'sender_type': 'contact',
          'sender_contact_id': '7266418340025468941',
          'sender_business_identity_id': null,
          'sender_business_identity_name': '',
          'content': '订单还没收到',
        },
        {
          'id': '7266418340025468962',
          'conversation_id': conversationId,
          'organization_id': orgId,
          'sender_type': 'business_identity',
          'sender_contact_id': null,
          'sender_business_identity_id': seatA,
          'sender_business_identity_name': '售后小张',
          'content': '正在核实',
        },
      ];

      // A 视角：detail(active v5, assignee=A) + 历史 2 条 + transfer 成功
      final adapterA = _SeqAdapter([
        ('/sessions/$sessionId', [(200, _detailBody('active', 5))]),
        (
          '/conversations/$conversationId/messages',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': history}),
          ],
        ),
        (
          '/transfer',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
      ]);
      final flowA = newFlow(store, adapterA);
      await flowA.refreshSessionState();
      await flowA.loadIncremental();
      expect(flowA.messages.map((m) => m.id).toList(), [
        '7266418340025468961',
        '7266418340025468962',
      ]);

      final failure = await flowA.transferTo(seatB);
      expect(failure, isNull, reason: 'A 转接成功');

      // B 视角：新 flow、同一共享 store；detail 回 assignee=B、v6；
      // 历史仍是同样两条（服务端不重写 sender/actor）
      final adapterB = _SeqAdapter([
        (
          '/sessions/$sessionId',
          [(200, _detailBody('active', 6, assignee: seatB))],
        ),
        (
          '/conversations/$conversationId/messages',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': history}),
          ],
        ),
      ]);
      HttpClient.adapterForTest = adapterB;
      addTearDown(() => HttpClient.adapterForTest = null);
      final flowB = CsSessionFlow(
        orgId: orgId,
        sessionId: sessionId,
        identityId: seatB,
        conversationId: conversationId,
        contactMaskedName: '张**',
        store: store,
      );

      final detailB = await flowB.refreshSessionState();
      await flowB.loadIncremental();

      // 资源 ID 不变（同 session / 同 conversation）
      expect(detailB?.sessionId, sessionId);
      expect(detailB?.conversationId, conversationId);
      expect(flowB.conversationId, conversationId);
      expect(detailB?.assigneeIdentityId, seatB, reason: '经办已切换为 B');

      // 消息 count 不变、id 集合一致
      expect(flowB.messages, hasLength(2));
      expect(
        flowB.messages.map((m) => m.id).toList(),
        flowA.messages.map((m) => m.id).toList(),
      );

      // 历史 sender/actor 不重写：visitor 仍 visitor、A 的出站仍署名 A
      final bVisitor = flowB.messages[0];
      final bSeat = flowB.messages[1];
      expect(bVisitor.senderType, EnterpriseSenderType.contact);
      expect(bVisitor.senderContactId, '7266418340025468941');
      expect(bSeat.senderType, EnterpriseSenderType.businessIdentity);
      expect(bSeat.senderBusinessIdentityId, seatA);
      expect(bSeat.senderBusinessIdentityName, '售后小张');
    });
  });

  group('CSM-03 个人数据边界（不转移/不删除/不写入）', () {
    test('全链路操作后本地缓存键全部 enterprise_ 前缀（APP-A02）', () async {
      final store = EnterpriseMemoryStore();
      final adapter = _SeqAdapter([
        ('/sessions/$sessionId', [(200, _detailBody('active', 5))]),
        (
          '/conversations/$conversationId/messages',
          [
            (
              200,
              {
                'code': 0,
                'msg': 'success',
                'payload': [
                  {
                    'id': '7266418340025468961',
                    'conversation_id': conversationId,
                    'organization_id': orgId,
                    'sender_type': 'contact',
                    'sender_contact_id': '7266418340025468941',
                    'sender_business_identity_id': null,
                    'content': 'hi',
                  },
                ],
              },
            ),
          ],
        ),
        (
          '/ack',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
      ]);
      final flow = newFlow(store, adapter);
      await flow.refreshSessionState();
      await flow.loadIncremental();
      await flow.send('回复');

      expect(store.debugKeys(), isNotEmpty);
      for (final key in store.debugKeys()) {
        expect(key.startsWith('enterprise_'), isTrue, reason: 'key=$key');
      }
    });

    test('customer_service 模块源码不 import 个人域 store/repo（静态扫描）', () {
      final banned = [
        'store/repository/user_repo',
        'store/model/user_model',
        'store/repository/contact_repo',
        'store/repository/message_repo',
        'page/chat/chat/attachment_handler',
        'service/assets.dart',
        'store/service/',
      ];
      final dir = io.Directory('lib/modules/customer_service');
      final files = dir
          .listSync(recursive: true)
          .whereType<io.File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        for (final pattern in banned) {
          expect(
            src.contains(pattern),
            isFalse,
            reason: '${f.path} 不得引用个人域：$pattern',
          );
        }
      }
    });
  });
}
