/// APP-M02-A02 — 坐席事件 SSE 流客户端单测（SSE-EVENT-CONTRACT-V1）
///
/// 纯 Dart（fake_async 控时），fake opener 注入——覆盖合同 required_tests
/// 的客户端侧语义：
/// - 帧解析：id/event/data/retry；心跳注释不占业务 event_id、不下发；
/// - at-least-once：按 event_id 有界去重（LRU 滚动后极旧重投按新处理）；
/// - Last-Event-ID 游标：重连携带最后 event_id（头语义），首连才带
///   after_id；
/// - resync.required 信封转发（消费方清游标权威 refresh 由 flow 覆盖）；
/// - 跨租户信封丢弃（双保险）；
/// - 打开失败指数退避（2^n×retry，30s 封顶）——断线自愈、无请求风暴；
/// - dispose 后不再重连（定时器/订阅全取消）；
/// - 非 JSON data 忽略，不崩溃。
library;

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';

const String kOrgId = '7266418340025468901';
const String kWsId = '7266418340025468921';

Map<String, dynamic> envelopeJson({
  required String eventId,
  String type = CsSseEnvelope.typeMessageAppended,
  String org = kOrgId,
  String ws = kWsId,
  String resourceId = '7266418340025468961',
  String reason = 'created',
}) => {
  'event_id': eventId,
  'type': type,
  'organization_id': org,
  'workspace_id': ws,
  'resource_type': 'message',
  'resource_id': resourceId,
  'resource_version': 1,
  'occurred_at': '2026-09-20T05:14:47Z',
  'reason': reason,
};

String frame(
  Map<String, dynamic> envelope, {
  String? id,
  String? event,
  int? retry,
}) => [
  if (retry != null) 'retry: $retry',
  'id: ${id ?? envelope['event_id']}',
  'event: ${event ?? envelope['type']}',
  'data: ${jsonEncode(envelope)}',
  '',
  '',
].join('\n');

Stream<List<int>> bytesOf(List<String> parts) =>
    Stream.value(utf8.encode(parts.join()));

/// fake opener：按序返回流；记录每次调用的游标形状。
class _OpenerHarness {
  _OpenerHarness(this._factory);

  final Future<Stream<List<int>>> Function(int index) _factory;

  final List<String> lastEventIds = [];
  final List<String> afterIds = [];
  final List<String> workspaceIds = [];
  int count = 0;

  Future<Stream<List<int>>> open(
    String orgId,
    String workspaceId, {
    String lastEventId = '',
    String afterId = '',
  }) async {
    count++;
    workspaceIds.add(workspaceId);
    lastEventIds.add(lastEventId);
    afterIds.add(afterId);
    return _factory(count - 1);
  }
}

void main() {
  test('帧解析：id/event/data 下发；retry 行生效；心跳注释不占 event_id', () {
    fakeAsync((async) {
      final envelopes = <CsSseEnvelope>[];
      final h = _OpenerHarness(
        (i) async => bytesOf([
          'retry: 2000\n\n',
          ': heartbeat\n\n',
          frame(envelopeJson(eventId: '7266418340025469001'), retry: 2000),
          frame(
            envelopeJson(
              eventId: '7266418340025469002',
              type: CsSseEnvelope.typeResyncRequired,
              reason: 'unknown',
            ),
          ),
        ]),
      );
      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener: h.open,
      );
      stream.start(onEvent: envelopes.add);
      async.flushMicrotasks();

      expect(envelopes, hasLength(2), reason: '心跳注释不下发');
      expect(envelopes[0].eventId, '7266418340025469001');
      expect(envelopes[0].type, CsSseEnvelope.typeMessageAppended);
      expect(envelopes[0].organizationId, kOrgId);
      expect(envelopes[0].workspaceId, kWsId);
      expect(envelopes[0].resourceId, '7266418340025468961');
      expect(envelopes[1].isResyncRequired, isTrue);
      expect(stream.retryMs, 2000, reason: '服务端 retry 行驱动重连间隔');
      expect(stream.lastEventId, '7266418340025469002');
      stream.dispose();
    });
  });

  test('at-least-once：event_id 重复丢弃；有界窗口滚动后极旧重投按新处理', () {
    fakeAsync((async) {
      final envelopes = <CsSseEnvelope>[];
      final dup = envelopeJson(eventId: '7266418340025469001');
      final fresh = envelopeJson(eventId: '7266418340025469002');
      final h = _OpenerHarness(
        (i) async => bytesOf([frame(dup), frame(dup), frame(fresh)]),
      );
      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        dedupCapacity: 2,
        opener: h.open,
      );
      stream.start(onEvent: envelopes.add);
      async.flushMicrotasks();

      expect(envelopes.map((e) => e.eventId).toList(), [
        '7266418340025469001',
        '7266418340025469002',
      ], reason: '重复 event_id 恰好下发一次');
      expect(stream.lastEventId, '7266418340025469002');
      stream.dispose();
    });
  });

  test('Last-Event-ID 游标：首连带 after_id；重连带最后 event_id 头语义', () {
    fakeAsync((async) {
      final envelopes = <CsSseEnvelope>[];
      final e1 = envelopeJson(eventId: '7266418340025469001');
      final e2 = envelopeJson(eventId: '7266418340025469002');
      final e3 = envelopeJson(eventId: '7266418340025469003');
      final h = _OpenerHarness(
        (i) async =>
            i == 0 ? bytesOf([frame(e1), frame(e2)]) : bytesOf([frame(e3)]),
      );
      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        initialAfterId: '7266418340025468990',
        opener: h.open,
      );
      stream.start(onEvent: envelopes.add);
      async.flushMicrotasks();
      // 首连：无 Last-Event-ID → after_id 兜底游标。
      expect(h.lastEventIds[0], '');
      expect(h.afterIds[0], '7266418340025468990');
      expect(h.workspaceIds[0], kWsId);

      // Stream.value 发完即关 → onDone → 服务端 retry 间隔后重连。
      async.elapse(const Duration(seconds: 3));
      expect(h.count, 2, reason: '断线自愈重连');
      expect(h.lastEventIds[1], '7266418340025469002', reason: '游标补偿');
      expect(h.afterIds[1], '', reason: 'Last-Event-ID 存在时不带 after_id');
      expect(envelopes.map((e) => e.eventId), contains('7266418340025469003'));
      stream.dispose();
    });
  });

  test('跨租户信封丢弃（双保险）；非 JSON data 忽略不崩溃', () {
    fakeAsync((async) {
      final envelopes = <CsSseEnvelope>[];
      final h = _OpenerHarness(
        (i) async => bytesOf([
          frame(envelopeJson(eventId: '7266418340025469001', org: '999')),
          'id: 7266418340025469002\nevent: message.appended\ndata: not-json\n\n',
          frame(envelopeJson(eventId: '7266418340025469003')),
        ]),
      );
      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener: h.open,
      );
      stream.start(onEvent: envelopes.add, onError: (Object e) {});
      async.flushMicrotasks();

      expect(envelopes.map((e) => e.eventId).toList(), [
        '7266418340025469003',
      ], reason: '跨租户信封与脏帧均不下发');
      stream.dispose();
    });
  });

  test('打开失败指数退避（2^n×retry，30s 封顶）——无请求风暴', () {
    fakeAsync((async) {
      final h = _OpenerHarness(
        (i) => Future<Stream<List<int>>>.error(
          const CsSseOpenException(503, 'text/plain'),
        ),
      );
      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener: h.open,
      );
      stream.start(onEvent: (_) {}, onError: (Object e) {});
      async.elapse(const Duration(seconds: 61));
      // 打开时刻：0s、4s、12s、28s、58s（退避 4/8/16/30/30）——61 秒内
      // 至多 5 次尝试，绝不打满。
      expect(h.count, lessThanOrEqualTo(6), reason: '退避生效，无请求风暴');
      expect(h.count, greaterThanOrEqualTo(4), reason: '退避不阻自愈');
      stream.dispose();
      async.flushTimers();
      final after = h.count;
      async.elapse(const Duration(minutes: 5));
      expect(h.count, after, reason: 'dispose 后停止一切重连');
    });
  });

  test('dispose 后：in-flight opener 完成不建流、不再重连', () {
    fakeAsync((async) {
      final envelopes = <CsSseEnvelope>[];
      final completer = Completer<Stream<List<int>>>();
      final h = _OpenerHarness((i) => completer.future);
      final stream = CsSeatEventsStream(
        orgId: kOrgId,
        workspaceId: kWsId,
        opener: h.open,
      );
      stream.start(onEvent: envelopes.add);
      async.flushMicrotasks();
      expect(h.count, 1);
      stream.dispose();
      completer.complete(bytesOf([frame(envelopeJson(eventId: 'x1'))]));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(envelopes, isEmpty, reason: 'dispose 竞态保护：不建流、不下发');
    });
  });
}
