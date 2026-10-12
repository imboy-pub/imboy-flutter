import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/domain/cs_conversation_history.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';
import 'package:imboy/service/storage.dart';

class HistoryApi extends CsApi {
  final queries = <Map<String, dynamic>>[];
  final acks = <String>[];
  final historyPaths = <String>[];
  final ackBodies = <Map<String, dynamic>>[];
  Future<IMBoyHttpResponse>? pending;
  Future<IMBoyHttpResponse>? pendingDetail;
  Map<String, dynamic>? readPayload;
  int total = 200;
  String? serverCursor;
  Future<IMBoyHttpResponse>? pendingAck;
  bool failAck = false;
  int readFailure = 0;
  int ackFailure = 0;
  final readIds = <int>{200};
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    if (uri.endsWith('/sessions/4') && pendingDetail != null) {
      return pendingDetail!;
    }
    if (uri.endsWith('/read-cursor')) {
      if (readFailure != 0) {
        return IMBoyHttpResponse.failure(
          errCode: readFailure,
          errMsg: 'denied',
        );
      }
      if (queryParameters?['workspace_id'] != '2') {
        return IMBoyHttpResponse.failure(
          errCode: 422,
          errMsg: 'missing workspace',
        );
      }
      if (readPayload != null) return IMBoyHttpResponse.success(readPayload);
      return IMBoyHttpResponse.success({
        'session_id': '4',
        'last_read_message_id':
            serverCursor ?? (acks.isEmpty ? '0' : acks.last),
        'unread_count': 20,
      });
    }
    historyPaths.add(uri);
    queries.add(Map.of(queryParameters!));
    if (pending != null) return pending!;
    final before = BigInt.tryParse('${queryParameters['before_id']}');
    final after =
        BigInt.tryParse('${queryParameters['after_id']}') ?? BigInt.zero;
    final desc = queryParameters['order'] == 'desc';
    final rows = List.generate(total, (i) => i + 1)
        .where(
          (i) => desc
              ? before == null || BigInt.from(i) < before
              : BigInt.from(i) > after,
        )
        .toList();
    if (desc) rows.sort((a, b) => b.compareTo(a));
    return IMBoyHttpResponse.success(
      rows
          .take(50)
          .map(
            (i) => {
              'id': '$i',
              'organization_id': '1',
              'conversation_id': '3',
              'sender_type': 'business_identity',
              'visibility': 'visible',
              'body': 'body $i',
              if (readIds.contains(i)) 'read_at': '2026-10-12T01:00:00.123456Z',
            },
          )
          .toList(),
    );
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    if (pendingAck != null) return pendingAck!;
    final body = data as Map<String, dynamic>;
    ackBodies.add(Map.of(body));
    acks.add('${body['last_read_message_id']}');
    if (body['workspace_id'] != '2') {
      return IMBoyHttpResponse.failure(
        errCode: 422,
        errMsg: 'missing workspace',
      );
    }
    if (ackFailure != 0) {
      return IMBoyHttpResponse.failure(errCode: ackFailure, errMsg: 'denied');
    }
    if (failAck) {
      return IMBoyHttpResponse.failure(errCode: 500, errMsg: 'failed');
    }
    return IMBoyHttpResponse.success(<String, dynamic>{});
  }

  @override
  Future<void> ackDelivery(
    String orgId,
    String conversationId,
    String messageId, {
    String workspaceId = '',
    required String recipientRef,
    String deviceId = '',
  }) async {}
}

class HintStream extends CsSeatEventsStream {
  HintStream() : super(orgId: '1', workspaceId: '2');
  void Function(CsSseEnvelope)? callback;
  @override
  void start({
    required void Function(CsSseEnvelope) onEvent,
    void Function(Object)? onError,
  }) {
    callback = onEvent;
  }

  @override
  void dispose() {}
}

CsSessionFlow flow(HistoryApi api, {bool Function()? current}) => CsSessionFlow(
  orgId: '1',
  sessionId: '4',
  workspaceId: '2',
  conversationId: '3',
  identityId: '5',
  csApi: api,
  store: EnterpriseMemoryStore(),
  scopeCurrent: current,
);
void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });
  test(
    'current read-state and visible ACK denial revoke loaded content',
    () async {
      for (final ack in [false, true]) {
        final api = HistoryApi();
        final f = flow(api);
        await f.loadLatest();
        if (ack) {
          api.ackFailure = 403;
          await f.ackVisibleMessages(['200']);
        } else {
          api.readFailure = 401;
          await f.resyncReadState();
        }
        expect(f.readRevoked, isTrue);
        expect(f.messages, isEmpty);
        expect(f.messageReadAt, isEmpty);
      }
    },
  );
  test(
    'refresh coalesces concurrent hints and discards late old scope',
    () async {
      final api = HistoryApi();
      var current = true;
      final f = flow(api, current: () => current);
      await f.loadLatest();
      final done = Completer<IMBoyHttpResponse>();
      api.pending = done.future;
      final before = api.queries.length;
      final first = f.refreshLoadedHistory();
      final second = f.refreshLoadedHistory();
      expect(api.queries.length, before + 1);
      current = false;
      done.complete(
        IMBoyHttpResponse.failure(errCode: 403, errMsg: 'old denied'),
      );
      await Future.wait([first, second]);
      expect(f.readRevoked, isFalse);
      expect(f.messages.length, 50);
      expect(api.queries.length, before + 1);
    },
  );
  test('read-state nonpermission failure hides stale unread', () async {
    final api = HistoryApi();
    final f = flow(api);
    await f.resyncReadState();
    expect(f.unreadCount, 20);
    api.readFailure = 500;
    await f.resyncReadState();
    expect(f.unreadCount, isNull);
    expect(f.readRevoked, isFalse);
  });
  test(
    'bounded refresh retains new messages and uncovered old receipt',
    () async {
      final api = HistoryApi()
        ..total = 1050
        ..readIds.add(1);
      final f = flow(api);
      await f.loadLatest();
      for (var i = 0; i < 20; i++) {
        await f.loadOlder();
      }
      expect(f.messages.length, 1050);
      final oldRead = f.messageReadAt['1'];
      api.total = 1051;
      api.readIds.add(1040);
      final before = api.queries.length;
      await f.refreshLoadedHistory();
      expect(api.queries.length - before, 20);
      expect(f.messages.last.id, '1051');
      expect(f.messageReadAt['1040'], isNotNull);
      expect(f.messageReadAt['1'], oldRead);
      expect(api.acks, isEmpty);
    },
  );
  test('ACK late success cannot regress larger resync cursor', () async {
    final api = HistoryApi();
    final f = flow(api);
    await f.loadLatest();
    final done = Completer<IMBoyHttpResponse>();
    api.pendingAck = done.future;
    final ack = f.ackVisibleMessages(['180']);
    api.serverCursor = '200';
    await f.resyncReadState();
    api.readFailure = 500;
    done.complete(IMBoyHttpResponse.success(<String, dynamic>{}));
    await ack;
    expect(f.ackedCursor, '200');
  });
  test('detail denial revokes only its still-current scope', () async {
    for (final current in [true, false]) {
      final api = HistoryApi();
      var active = true;
      final f = flow(api, current: () => active);
      await f.loadLatest();
      final done = Completer<IMBoyHttpResponse>();
      api.pendingDetail = done.future;
      final request = f.refreshSessionState();
      active = current;
      done.complete(IMBoyHttpResponse.failure(errCode: 403, errMsg: 'denied'));
      await request;
      expect(f.readRevoked, current);
      expect(f.messages.isEmpty, current);
      expect(f.messageReadAt.isEmpty, current);
    }
  });
  test('resync restores latest beyond oldest page without read ACK', () async {
    final api = HistoryApi();
    final f = flow(api);
    await f.loadLatest();
    await f.loadOlder();
    api.total = 201;
    api.pendingDetail = Future.value(
      IMBoyHttpResponse.success({
        'session_id': '4',
        'organization_id': '1',
        'conversation_id': '3',
        'business_identity_id': '5',
        'status': 'active',
        'version': 1,
      }),
    );
    final stream = HintStream();
    f.bindEvents(stream);
    stream.callback!(
      const CsSseEnvelope(
        eventId: '301',
        type: 'resync.required',
        organizationId: '1',
        workspaceId: '2',
        resourceType: 'session',
        resourceId: '4',
        reason: 'cursor_expired',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(f.messages.last.id, '201');
    expect(f.messages.any((m) => m.id == '101'), isTrue);
    expect(api.acks, isEmpty);
  });
  test(
    'read-state accepts real zero cursor and strict nonnegative counts',
    () async {
      final api = HistoryApi();
      for (final cursor in [0, '0', 200, '200']) {
        for (final count in [0, 3]) {
          api.readPayload = {
            'session_id': '4',
            'last_read_message_id': cursor,
            'unread_count': count,
          };
          final state = await fetchCsReadState(api, '1', '2', '4');
          expect(state.lastReadMessageId, '$cursor');
          expect(state.unreadCount, count);
        }
      }
    },
  );
  test(
    'read-state refuses malformed count and cursor rather than fake zero',
    () async {
      final api = HistoryApi();
      for (final value in [null, true, 1.5, -1, '0']) {
        api.readPayload = {
          'session_id': '4',
          'last_read_message_id': 0,
          'unread_count': value,
        };
        await expectLater(
          fetchCsReadState(api, '1', '2', '4'),
          throwsA(isA<CsApiException>()),
        );
      }
      api.readPayload = {'session_id': '4', 'last_read_message_id': 0};
      await expectLater(
        fetchCsReadState(api, '1', '2', '4'),
        throwsA(isA<CsApiException>()),
      );
      for (final value in [-1, 1.5, true, 'abc', '9223372036854775808']) {
        api.readPayload = {
          'session_id': '4',
          'last_read_message_id': value,
          'unread_count': 0,
        };
        await expectLater(
          fetchCsReadState(api, '1', '2', '4'),
          throwsA(isA<CsApiException>()),
        );
      }
    },
  );
  test('latest + three older pages yield numeric ASC 200 unique; refresh retains older and true read fact', () async {
    final api = HistoryApi();
    final f = flow(api);
    await f.loadLatest();
    for (var i = 0; i < 3; i++) {
      await f.loadOlder();
    }
    expect(
      f.messages.map((m) => m.id).toList(),
      List.generate(200, (i) => '${i + 1}'),
    );
    expect(api.queries.map((q) => q['before_id']).toList(), [
      null,
      '151',
      '101',
      '51',
    ]);
    expect(
      api.queries.every((q) => q['limit'] == 50 && q['order'] == 'desc'),
      isTrue,
    );
    expect(
      f.messageReadAt['200'],
      DateTime.parse('2026-10-12T01:00:00.123456Z'),
    );
    await f.loadLatest();
    expect(f.messages.length, 200);
    expect(api.acks, isEmpty);
  });
  test('only explicitly visible loaded members ACK; failure retries and duplicate/old no-op', () async {
    final api = HistoryApi();
    final f = flow(api);
    await f.loadLatest();
    await f.ackVisibleMessages(['999', '1']);
    expect(api.acks, isEmpty);
    api.failAck = true;
    await f.ackVisibleMessages(['180']);
    expect(f.ackedCursor, isEmpty);
    api.failAck = false;
    await f.ackVisibleMessages(['180']);
    expect(f.ackedCursor, '180');
    await f.ackVisibleMessages(['179', '180']);
    expect(api.acks, ['180', '180']);
    expect(api.ackBodies, [
      {'workspace_id': '2', 'last_read_message_id': '180'},
      {'workspace_id': '2', 'last_read_message_id': '180'},
    ]);
  });
  test(
    'old scope late response cannot populate new scope or cause ACK',
    () async {
      final api = HistoryApi();
      final gate = Completer<IMBoyHttpResponse>();
      api.pending = gate.future;
      var current = true;
      final f = flow(api, current: () => current);
      final request = f.loadLatest();
      await Future<void>.delayed(Duration.zero);
      current = false;
      gate.complete(
        IMBoyHttpResponse.success([
          {
            'id': '200',
            'organization_id': '1',
            'conversation_id': '3',
            'body': 'old',
          },
        ]),
      );
      await request;
      expect(f.messages, isEmpty);
      await f.ackVisibleMessages(['200']);
      expect(api.acks, isEmpty);
    },
  );
  test('disposed page rejects late history and later dispatch', () async {
    final api = HistoryApi();
    final gate = Completer<IMBoyHttpResponse>();
    api.pending = gate.future;
    final f = flow(api);
    final request = f.loadLatest();
    await Future<void>.delayed(Duration.zero);
    f.dispose();
    gate.complete(IMBoyHttpResponse.success(<dynamic>[]));
    await request;
    await f.loadOlder();
    expect(api.queries.length, 1);
    expect(f.messages, isEmpty);
  });
  for (final code in [401, 403]) {
    test(
      'current $code revokes body cache and prevents subsequent dispatch',
      () async {
        final api = HistoryApi();
        final f = flow(api);
        await f.loadLatest();
        api.pending = Future.value(
          IMBoyHttpResponse.failure(errCode: code, errMsg: 'denied'),
        );
        await f.loadLatest();
        final count = api.queries.length;
        expect(f.readRevoked, isTrue);
        expect(f.messages, isEmpty);
        expect(f.messageReadAt, isEmpty);
        await f.loadOlder();
        await f.loadIncremental();
        await f.ackVisibleMessages(['200']);
        expect(api.queries.length, count);
        expect(api.acks, isEmpty);
      },
    );
  }
  test('receipt rejects contact/hidden/non UTC timestamps and malformed page scope', () {
    final row = {
      'id': '200',
      'organization_id': '1',
      'conversation_id': '3',
      'sender_type': 'business_identity',
      'visibility': 'visible',
      'read_at': '2026-10-12T01:00:00Z',
    };
    expect(parseCsHistoryPage([row], '1', '3', latest: true).readAt.keys, [
      '200',
    ]);
    for (final change in [
      {'sender_type': 'contact'},
      {'visibility': 'hidden'},
      {'read_at': '2026-10-12T01:00:00+08:00'},
      {'read_at': 'bad'},
      {'read_at': '2026-02-31T01:00:00Z'},
      {'read_at': '2026-13-01T01:00:00Z'},
      {'read_at': '2026-10-12T24:00:00Z'},
      {'read_at': '2026-10-12T01:60:00Z'},
      {'read_at': '2026-10-12T01:00:60Z'},
    ]) {
      expect(
        parseCsHistoryPage(
          [
            {...row, ...change},
          ],
          '1',
          '3',
          latest: true,
        ).readAt,
        isEmpty,
      );
    }
    expect(
      () => parseCsHistoryPage(
        [
          {...row, 'organization_id': '9'},
        ],
        '1',
        '3',
        latest: true,
      ),
      throwsA(isA<CsApiException>()),
    );
    expect(
      () => parseCsHistoryPage([row, row], '1', '3', latest: true),
      throwsA(isA<CsApiException>()),
    );
  });
  test('late old latest request cannot overwrite new receipt or revoke current read', () async {
    final api = HistoryApi();
    final old = Completer<IMBoyHttpResponse>();
    api.pending = old.future;
    final f = flow(api);
    final a = f.loadLatest();
    await Future<void>.delayed(Duration.zero);
    api.pending = Future.value(
      IMBoyHttpResponse.success([
        {
          'id': '200',
          'organization_id': '1',
          'conversation_id': '3',
          'sender_type': 'business_identity',
          'visibility': 'visible',
          'read_at': '2026-10-12T01:00:00Z',
        },
      ]),
    );
    await f.loadLatest();
    old.complete(IMBoyHttpResponse.failure(errCode: 403, errMsg: 'old denial'));
    await a;
    expect(f.readRevoked, isFalse);
    expect(f.messageReadAt['200'], DateTime.parse('2026-10-12T01:00:00Z'));
  });
  test(
    'message read hint refreshes an already loaded older ID without local ACK',
    () async {
      final api = HistoryApi();
      final f = flow(api);
      await f.loadLatest();
      for (var i = 0; i < 3; i++) {
        await f.loadOlder();
      }
      expect(f.messageReadAt['20'], isNull);
      api.readIds.add(20);
      final stream = HintStream();
      f.bindEvents(stream);
      stream.callback!(
        const CsSseEnvelope(
          eventId: '300',
          type: 'message.appended',
          organizationId: '1',
          workspaceId: '2',
          resourceType: 'message',
          resourceId: '20',
          reason: 'updated',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        f.messageReadAt['20'],
        DateTime.parse('2026-10-12T01:00:00.123456Z'),
      );
      expect(api.acks, isEmpty);
      expect(f.messages.length, 200);
      f.dispose();
    },
  );
}
