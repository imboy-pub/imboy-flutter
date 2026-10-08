/// CS-APP-02（CS-RUNTIME-04）— presence 心跳门控 + 已读游标/未读单测
///
/// before-failing 语义四钉（改动前这些行为缺失，本文件钉住回归）：
/// 1. **后台停跳**：paused/detached/hidden 后周期 timer 不再发 heartbeat
///    （不保持假 online——90 秒无心跳由服务端判 offline）；
/// 2. **resume 重同步**：resumed 立即补跳一次 + onResync 触发一次；
/// 3. **ACK 时机**：进入会话「权威展示完成」才 ACK（单调推进；旧值/
///    空值不发；重复展示完成不重发）；
/// 4. **离线重连无陈旧未读**：resync.required 先清未读（null 不渲染）→
///    先重拉 read-cursor 权威值（可观察地阻塞在 GET 上）→ 再增量拉消息
///    → 展示完成后 ACK 清零；ACK 失败不本地伪读。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/public.dart';
import 'package:imboy/modules/enterprise/public.dart'
    show EnterpriseMemoryStore;
import 'package:imboy/service/storage.dart';

const kOrgId = '7266418340025468901';
const kWsId = '7266418340025468921';
const kConvId = '7266418340025468950';
const kSessionId = '7266418340025468940';
const kIdentityId = '7266418340025468902';
const kMsg1 = '7266418340025468961';
const kMsg2 = '7266418340025468962';

CsPresence _presence(
  CsPresenceStatus status, {
  String? manual,
  bool enabled = true,
}) => CsPresence(
  status: status,
  manualStatus: manual,
  enabled: enabled,
  maxConcurrent: 3,
  activeCount: 1,
  lastHeartbeatAt: 100,
);

/// 假 CsApi：只实现 presence 面（heartbeat / manual），不经 dio——控制器
/// 单测聚焦门控语义，不牵 HTTP 链。
class _FakeCsApi extends CsApi {
  final Object? heartbeatError;
  int heartbeats = 0;
  final List<String?> manualCalls = [];
  final List<String> heartbeatWorkspaceIds = [];

  _FakeCsApi({this.heartbeatError});

  @override
  Future<CsPresence> seatHeartbeat(
    String orgId, {
    String workspaceId = '',
  }) async {
    heartbeatWorkspaceIds.add(workspaceId);
    heartbeats++;
    final error = heartbeatError;
    if (error != null) throw error;
    return _presence(CsPresenceStatus.online);
  }

  @override
  Future<CsPresence> setSeatPresence(
    String orgId,
    String? manualStatus, {
    String workspaceId = '',
  }) async {
    manualCalls.add(manualStatus);
    return _presence(
      manualStatus == 'away' ? CsPresenceStatus.away : CsPresenceStatus.online,
      manual: manualStatus,
    );
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('CS-RUNTIME-04 presence 心跳门控（CsPresenceController）', () {
    test('后台停跳：paused 后周期不再发；resume 立即补跳 + 重同步一次', () {
      fakeAsync((async) async {
        final api = _FakeCsApi();
        var resyncs = 0;
        final controller = CsPresenceController(
          csApi: api,
          orgId: kOrgId,
          workspaceId: kWsId,
          interval: const Duration(seconds: 30),
          onResync: () async => resyncs++,
        );
        controller.start();
        async.flushMicrotasks();
        expect(api.heartbeats, 1, reason: '启动即一次心跳');
        expect(
          api.heartbeatWorkspaceIds.single,
          kWsId,
          reason: 'CSB-02R workspace 门必填键随心跳提交',
        );

        // 前台：30s 周期心跳正常推进。
        async.elapse(const Duration(seconds: 90));
        expect(api.heartbeats, 4, reason: '30s×3 周期 + 启动一次');

        // 进后台（paused）：停发——不保持假 online。
        unawaited(controller.onAppLifecycleStateChanged('paused'));
        async.flushMicrotasks();
        final pausedAt = api.heartbeats;
        async.elapse(const Duration(seconds: 150));
        expect(api.heartbeats, pausedAt, reason: '后台停跳（5 个周期零心跳）');
        expect(controller.foreground, isFalse);

        // resume：立即补跳一次 + 触发重同步一次。
        await controller.onAppLifecycleStateChanged('resumed');
        expect(api.heartbeats, pausedAt + 1, reason: 'resume 立即补跳');
        expect(resyncs, 1, reason: 'resume 重同步恰好一次');
        expect(controller.foreground, isTrue);

        // 回前台后周期心跳恢复。
        async.elapse(const Duration(seconds: 30));
        expect(api.heartbeats, pausedAt + 2, reason: '周期心跳恢复');

        // stop（dispose）：彻底停止。
        controller.stop();
        async.elapse(const Duration(seconds: 60));
        expect(api.heartbeats, pausedAt + 2, reason: 'stop 后不再心跳');
      });
    });

    test('心跳失败诚实降级：lastPresence=null（本地不造状态）+ 通知 UI', () async {
      // StateError 是 Error 非 Exception——on Object 兜底：心跳链路永不
      // 向 UI 抛（对齐 Web「断网不得显示 online」）。
      final api = _FakeCsApi(heartbeatError: StateError('network gone'));
      var notified = 0;
      final controller = CsPresenceController(
        csApi: api,
        orgId: kOrgId,
        workspaceId: kWsId,
        onPresenceChanged: () => notified++,
      );
      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(api.heartbeats, 1);
      expect(controller.lastPresence, isNull, reason: '失败不保留旧 online');
      expect(notified, greaterThanOrEqualTo(1), reason: '失败也通知重建');
      controller.stop();
    });

    test('手动 away / 恢复自动：PUT 结果回填服务端派生事实', () async {
      final api = _FakeCsApi();
      final controller = CsPresenceController(
        csApi: api,
        orgId: kOrgId,
        workspaceId: kWsId,
      );

      await controller.setManualStatus('away');
      expect(api.manualCalls, ['away']);
      expect(controller.lastPresence?.status, CsPresenceStatus.away);
      expect(controller.lastPresence?.manualStatus, 'away');

      await controller.setManualStatus(null);
      expect(api.manualCalls, ['away', null]);
      expect(controller.lastPresence?.status, CsPresenceStatus.online);
      expect(controller.lastPresence?.manualStatus, isNull);
    });

    test('workspaceId 为空：心跳诚实不发（CSB-02R 必填，发了必 422）', () {
      fakeAsync((async) async {
        final api = _FakeCsApi();
        final controller = CsPresenceController(
          csApi: api,
          orgId: kOrgId,
          workspaceId: '',
          interval: const Duration(seconds: 30),
        );
        controller.start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));
        expect(api.heartbeats, 0, reason: '缺 workspace 不发注定失败的请求');
        expect(controller.lastPresence, isNull, reason: '本地不造状态');
        controller.stop();
      });
    });
  });

  group('CS-RUNTIME-04 ACK 单调裁决（nextAckTarget 纯函数）', () {
    test('空/旧值不发；只有更大的消息 id 才推进', () {
      expect(nextAckTarget(current: null, seen: null), isNull);
      expect(nextAckTarget(current: '500', seen: ''), isNull);
      expect(nextAckTarget(current: null, seen: kMsg1), kMsg1);
      expect(
        nextAckTarget(current: kMsg2, seen: kMsg1),
        isNull,
        reason: '旧值：服务端本就 no-op，本地也不发',
      );
      expect(
        nextAckTarget(current: kMsg2, seen: kMsg2),
        isNull,
        reason: '等值不重发',
      );
      expect(nextAckTarget(current: kMsg1, seen: kMsg2), kMsg2);
    });

    test('TSID 十进制语义：长度不同先比长度（跨位数不字典序）', () {
      expect(
        nextAckTarget(current: '999', seen: '1000'),
        '1000',
        reason: '4 位必大于 3 位',
      );
      expect(nextAckTarget(current: '1000', seen: '999'), isNull);
    });
  });

  group('CS-RUNTIME-04 已读游标/未读（CsSessionFlow）', () {
    Map<String, dynamic> readStateBody(String cursor, int unread) => {
      'code': 0,
      'msg': 'success',
      'payload': {
        'session_id': kSessionId,
        'business_identity_id': kIdentityId,
        'last_read_message_id': cursor,
        'unread_count': unread,
      },
    };

    Map<String, dynamic> detailBody({String assignee = kIdentityId}) => {
      'code': 0,
      'msg': 'success',
      'payload': {
        'session_id': kSessionId,
        'organization_id': kOrgId,
        'conversation_id': kConvId,
        'status': 'active',
        'version': 5,
        'business_identity_id': assignee,
      },
    };

    Map<String, dynamic> historyBody() => {
      'code': 0,
      'msg': 'success',
      'payload': [
        {
          'id': kMsg1,
          'conversation_id': kConvId,
          'organization_id': kOrgId,
          'sender_type': 'contact',
          'sender_contact_id': '7266418340025468941',
          'sender_business_identity_id': null,
          'content': '订单还没收到',
          'delivered': true,
          'assets': <Map<String, dynamic>>[],
        },
        {
          'id': kMsg2,
          'conversation_id': kConvId,
          'organization_id': kOrgId,
          'sender_type': 'contact',
          'sender_contact_id': '7266418340025468941',
          'sender_business_identity_id': null,
          'content': '还在吗',
          'delivered': true,
          'assets': <Map<String, dynamic>>[],
        },
      ],
    };

    /// fragment 路由桩（复制 cs_session_flow_test 款式；更长 fragment
    /// 先注册——'/read-cursor' 必须先于 '/sessions/:id'）。
    _RouteAdapter bootstrapAdapter({
      required (int, Map<String, dynamic>) ackResponse,
    }) => _RouteAdapter([
      ('/read-cursor', [(200, readStateBody(kMsg1, 2)), ackResponse]),
      ('/sessions/$kSessionId', [(200, detailBody())]),
      ('conversations/$kConvId/messages', [(200, historyBody())]),
    ]);

    CsSessionFlow newFlow(HttpClientAdapter adapter) {
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      return CsSessionFlow(
        orgId: kOrgId,
        sessionId: kSessionId,
        identityId: kIdentityId,
        conversationId: kConvId,
        workspaceId: kWsId,
        contactMaskedName: '张**',
        store: EnterpriseMemoryStore(),
      );
    }

    test('ACK 时机：先重同步读状态 → 拉消息（展示完成）→ 才 ACK 最大已见 id；重复展示不重发', () async {
      final adapter = bootstrapAdapter(
        ackResponse: (200, {'code': 0, 'msg': 'success', 'payload': null}),
      );
      final flow = newFlow(adapter);

      // 会话页 bootstrap 同序链（权威展示完成后 ACK）。
      await flow.refreshSessionState();
      await flow.resyncReadState();
      expect(flow.unreadCount, 2, reason: '进入会话先取服务端权威未读');
      await flow.loadIncremental();
      await flow.ackReadSeen();

      final ackPosts = adapter.requests
          .where((r) => r.$1 == 'POST' && r.$2.contains('/read-cursor'))
          .toList();
      expect(ackPosts, hasLength(1), reason: '展示完成后恰好 ACK 一次');
      expect(
        (ackPosts.single.$3 as Map<String, dynamic>)['last_read_message_id'],
        kMsg2,
        reason: 'ACK 目标 = 已加载最大消息 id（单调推进）',
      );
      expect(flow.ackedCursor, kMsg2);
      expect(flow.unreadCount, 0, reason: '本端刚读完，未读清零');

      // 顺序钉：读状态 GET 在消息 GET 之前（重连后先重同步 cursor）。
      final readGetIdx = adapter.requests.indexWhere(
        (r) => r.$1 == 'GET' && r.$2.contains('/read-cursor'),
      );
      final msgGetIdx = adapter.requests.indexWhere(
        (r) =>
            r.$1 == 'GET' && r.$2.contains('conversations/$kConvId/messages'),
      );
      expect(readGetIdx, lessThan(msgGetIdx));

      // 无新消息：再次「展示完成」不重发 ACK（单调裁决吞旧值）。
      await flow.loadIncremental();
      await flow.ackReadSeen();
      final ackCount2 = adapter.requests
          .where((r) => r.$1 == 'POST' && r.$2.contains('/read-cursor'))
          .length;
      expect(ackCount2, 1, reason: '旧值/等值不发，不重发 ACK');
      flow.dispose();
    });

    test('ACK 失败不本地伪读：水位与未读保持服务端权威值', () async {
      final adapter = bootstrapAdapter(
        ackResponse: (500, {'code': 500, 'msg': 'server error'}),
      );
      final flow = newFlow(adapter);

      await flow.refreshSessionState();
      await flow.resyncReadState();
      await flow.loadIncremental();
      await flow.ackReadSeen();

      expect(flow.ackedCursor, kMsg1, reason: 'ACK 失败：本地水位不推进');
      expect(flow.unreadCount, 2, reason: 'ACK 失败：未读不清零（不伪读）');
      flow.dispose();
    });

    test('离线重连（resync.required）：陈旧未读立即失效，先重同步 cursor 再渲染消息，展示完成后 ACK', () async {
      final adapter = _GateAdapter(
        firstReadState: readStateBody(kMsg1, 5),
        secondReadState: readStateBody(kMsg1, 3),
        detailDelay: const Duration(milliseconds: 100),
        detail: detailBody(),
        history: historyBody(),
      );
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      final resyncCompleted = Completer<void>();
      final flow = CsSessionFlow(
        orgId: kOrgId,
        sessionId: kSessionId,
        identityId: kIdentityId,
        conversationId: kConvId,
        workspaceId: kWsId,
        contactMaskedName: '张**',
        onChanged: () {
          if (!resyncCompleted.isCompleted) resyncCompleted.complete();
        },
        store: EnterpriseMemoryStore(),
      );

      addTearDown(flow.dispose);

      // 断线前的本地快照（陈旧源）：未读 5。
      await flow.resyncReadState();
      expect(flow.unreadCount, 5);

      // 重连：SSE 下发 resync.required。
      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener:
            (
              orgId,
              workspaceId, {
              String lastEventId = '',
              String afterId = '',
            }) async => Stream.value(
              utf8.encode(
                'id: 7266418340025469002\nevent: resync.required\n'
                'data: ${jsonEncode({'event_id': '7266418340025469002', 'type': 'resync.required', 'organization_id': kOrgId, 'workspace_id': kWsId, 'resource_type': 'session', 'resource_id': kSessionId, 'resource_version': 6, 'occurred_at': '2026-09-24T05:14:47Z', 'reason': 'reconnect'})}\n\n',
              ),
            ),
      );
      flow.bindEvents(stream);
      // 读状态 GET 被闸住：此窗口内断言「陈旧未读已失效、消息未渲染」。
      await adapter.secondReadRequested.future.timeout(
        const Duration(seconds: 5),
      );
      expect(flow.unreadCount, isNull, reason: 'resync 后陈旧未读立即失效（null = 不渲染）');
      expect(
        adapter.messagesFetched,
        isFalse,
        reason: '先重同步 cursor（GET 悬停），消息增量未发出',
      );
      expect(adapter.readStateGets, 2, reason: '权威重拉已发出');

      // 放行：重同步完成 → 增量消息 → 展示完成 ACK。
      adapter.gate.complete();
      await resyncCompleted.future.timeout(const Duration(seconds: 5));

      expect(adapter.messagesFetched, isTrue);
      final order = adapter.methodPathLog;
      final secondReadIdx = order.lastIndexOf('GET /read-cursor');
      final msgIdx = order.indexOf('GET /messages');
      final ackIdx = order.indexOf('POST /read-cursor');
      expect(secondReadIdx, lessThan(msgIdx), reason: '先重同步 cursor 再拉消息渲染');
      expect(msgIdx, lessThan(ackIdx), reason: '展示完成后才 ACK');
      expect(flow.ackedCursor, kMsg2);
      expect(flow.unreadCount, 0, reason: 'ACK 后未读清零，不残留重连前的 5');
    });

    test('转接后未读陈旧化：transferredAway 终态不渲染旧坐席视角未读', () async {
      // fragment 按注册顺序命中：'/read-cursor' 必须先于 '/sessions/:id'
      //（read-cursor 路径也包含 sessions 段）。
      final adapter = _RouteAdapter([
        ('/read-cursor', [(200, readStateBody(kMsg1, 4))]),
        (
          '/sessions/$kSessionId',
          [
            (200, detailBody()),
            (200, detailBody(assignee: '7266418340025468999')),
          ],
        ),
        (
          '/transfer',
          [
            (200, {'code': 0, 'msg': 'success', 'payload': null}),
          ],
        ),
      ]);
      final flow = newFlow(adapter);

      await flow.refreshSessionState();
      await flow.resyncReadState();
      expect(flow.unreadCount, 4);

      final failure = await flow.transferTo('7266418340025468999');
      expect(failure, isNull, reason: '转接成功');
      expect(flow.unreadCount, isNull, reason: '转接后未读陈旧化（不渲染）');

      // 撤权表现（403 降级）同样清未读。
      flow.applyFailure(const CsApiException(403, 'forbidden'));
      expect(flow.unreadCount, isNull);
      flow.dispose();
    });
  });
}

/// fragment 路由桩（对齐 cs_session_flow_test._RouteAdapter；记录
/// method/fullUri/data/query）。
class _RouteAdapter implements HttpClientAdapter {
  _RouteAdapter(this.routes);

  final List<(String fragment, List<(int, Map<String, dynamic>)> responses)>
  routes;
  final Map<String, int> _cursors = {};
  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

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

/// 重连测试专用桩：第二次 GET read-cursor 被 [gate] 悬停——用于可观察地
/// 断言「先重同步 cursor 再渲染消息」的顺序。
class _GateAdapter implements HttpClientAdapter {
  _GateAdapter({
    required this.firstReadState,
    required this.secondReadState,
    required this.detail,
    required this.history,
    this.detailDelay = Duration.zero,
  }) : gate = Completer<void>();

  final Map<String, dynamic> firstReadState;
  final Map<String, dynamic> secondReadState;
  final Map<String, dynamic> detail;
  final Map<String, dynamic> history;
  final Completer<void> gate;
  final Duration detailDelay;
  final secondReadRequested = Completer<void>();

  int readStateGets = 0;
  bool messagesFetched = false;
  final List<String> methodPathLog = [];
  Object? ackBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final method = options.method;
    if (path.contains('/read-cursor')) {
      if (method == 'GET') {
        readStateGets++;
        methodPathLog.add('GET /read-cursor');
        if (readStateGets == 2) {
          secondReadRequested.complete();
          await gate.future;
        }
        return _json(readStateGets == 1 ? firstReadState : secondReadState);
      }
      ackBody = options.data;
      methodPathLog.add('POST /read-cursor');
      return _json({'code': 0, 'msg': 'success', 'payload': null});
    }
    if (path.contains('/sessions/$kSessionId')) {
      methodPathLog.add('GET /sessions');
      await Future<void>.delayed(detailDelay);
      return _json(detail);
    }
    if (path.contains('conversations/$kConvId/messages')) {
      messagesFetched = true;
      methodPathLog.add('GET /messages');
      return _json(history);
    }
    methodPathLog.add('$method other');
    return _json({'code': 0, 'msg': 'success', 'payload': null});
  }

  ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
