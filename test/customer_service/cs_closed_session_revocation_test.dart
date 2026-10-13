import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

class RefusingDetailApi extends CsApi {
  int calls = 0;
  int code = 403;
  Completer<CsSessionDetail>? pending;
  CsSessionDetail? result;
  @override
  Future<CsSessionDetail> sessionDetail(
    String org,
    String session, {
    String workspaceId = '',
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    if (result != null) return result!;
    throw CsApiException(code, 'synthetic-refusal');
  }
}

CsSessionFlow seededFlow(
  CsApi api, {
  bool rated = true,
  bool Function()? current,
  void Function()? changed,
}) {
  final flow = CsSessionFlow(
    orgId: '1',
    workspaceId: '2',
    sessionId: '4',
    conversationId: '3',
    identityId: '5',
    csApi: api,
    scopeCurrent: current ?? () => true,
    onChanged: changed,
  );
  flow.machine.markClosed();
  if (rated) flow.machine.markRated();
  flow.detail = CsSessionDetail(
    sessionId: '4',
    organizationId: '1',
    conversationId: '3',
    status: 'closed',
    rating: rated ? 4 : 0,
    evaluationState: rated
        ? CsEvaluationState.rated
        : CsEvaluationState.unrated,
    ratingAt: rated ? DateTime.utc(2026, 10, 13) : null,
  );
  flow.messages = [
    const EnterpriseMessage(
      id: '100',
      organizationId: '1',
      conversationId: '3',
      content: 'synthetic-protected-body',
    ),
  ];
  flow.messageAssets = {
    '100': [const CsMessageAsset(id: '9', status: 'active')],
  };
  flow.messageReadAt = {'100': DateTime.utc(2026, 10, 13)};
  return flow;
}

CsSeatEventsStream bindStream(CsSessionFlow flow, Stream<List<int>> bytes) {
  final stream = CsSeatEventsStream(
    orgId: '1',
    workspaceId: '2',
    opener: (org, ws, {lastEventId = '', afterId = ''}) async => bytes,
  );
  flow.bindEvents(stream);
  addTearDown(flow.dispose);
  return stream;
}

List<int> event(
  String type, {
  String workspace = '2',
  String org = '1',
  String resource = '5',
}) => utf8.encode(
  'id: 101\nevent: $type\ndata: '
  '${jsonEncode({'event_id': '101', 'type': type, 'organization_id': org, 'workspace_id': workspace, 'resource_id': resource, 'reason': 'revoked'})}\n\n',
);
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));
void expectWithdrawn(CsSessionFlow flow) {
  expect(flow.readRevoked, isTrue);
  expect(flow.messages, isEmpty);
  expect(flow.detail, isNull);
  expect(flow.messageAssets, isEmpty);
  expect(flow.messageReadAt, isEmpty);
  expect(flow.machine.canDownload, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerScopedRefusal();
  _registerIsolation();
  _registerLateIsolation();
  _registerOrdinaryHint();
  _registerEmptyResources();
  _registerStreamRefusal();
  _registerDioContract();
  _registerLegalClosedRead();
  _registerRealStreamRefusal();
  _registerResolvedWorkspace();
  _registerLateDetailAfterRevoke();
}

void _registerScopedRefusal() {
  for (final rated in [false, true]) {
    for (final type in [
      'seat.changed',
      'assignment.changed',
      'resync.required',
    ]) {
      test(
        '$rated closed/rated $type reaches authority and withdraws all facts',
        () async {
          final api = RefusingDetailApi();
          var changes = 0;
          final flow = seededFlow(api, rated: rated, changed: () => changes++);
          final stream = bindStream(
            flow,
            Stream.value(
              event(type, resource: type == 'resync.required' ? '' : '5'),
            ),
          );
          await settle();
          expect(api.calls, 1);
          expectWithdrawn(flow);
          expect(changes, greaterThan(0));
          expect(stream.isConnected, false);
        },
      );
    }
  }
  test('current rated authority401 is also fail closed', () async {
    final api = RefusingDetailApi()..code = 401;
    final flow = seededFlow(api);
    bindStream(flow, Stream.value(event('seat.changed')));
    await settle();
    expectWithdrawn(flow);
  });
}

void _registerIsolation() {
  for (final variant in [('2', '9', '5'), ('9', '1', '5'), ('2', '1', '999')]) {
    test(
      'foreign scope/resource event cannot revoke rated view $variant',
      () async {
        final api = RefusingDetailApi();
        final flow = seededFlow(api);
        bindStream(
          flow,
          Stream.value(
            event(
              'seat.changed',
              workspace: variant.$1,
              org: variant.$2,
              resource: variant.$3,
            ),
          ),
        );
        await settle();
        expect(api.calls, 0);
        expect(flow.readRevoked, false);
        expect(flow.messages, hasLength(1));
      },
    );
  }
}

void _registerLateIsolation() {
  test(
    'late refusal from obsolete A cannot notify or erase current B',
    () async {
      final api = RefusingDetailApi()..pending = Completer<CsSessionDetail>();
      var current = true, changes = 0;
      final a = seededFlow(
        api,
        current: () => current,
        changed: () => changes++,
      );
      final b = seededFlow(RefusingDetailApi());
      bindStream(a, Stream.value(event('seat.changed')));
      await settle();
      expect(api.calls, 1);
      current = false;
      api.pending!.completeError(
        const CsApiException(403, 'synthetic-refusal'),
      );
      await settle();
      expect(changes, 0);
      expect(b.readRevoked, false);
      expect(b.messages, hasLength(1));
      b.dispose();
    },
  );
}

void _registerOrdinaryHint() {
  test('rated message hint does not start ordinary history polling', () async {
    final api = RefusingDetailApi();
    final flow = seededFlow(api);
    bindStream(flow, Stream.value(event('message.appended', resource: '100')));
    await settle();
    expect(api.calls, 0);
    expect(flow.readRevoked, false);
  });
}

void _registerStreamRefusal() {
  test(
    'rated SSE authentication rejection withdraws rather than reconnects',
    () async {
      final api = RefusingDetailApi();
      final flow = seededFlow(api);
      final stream = CsSeatEventsStream(
        orgId: '1',
        workspaceId: '2',
        opener: (org, ws, {lastEventId = '', afterId = ''}) async =>
            throw const CsSseOpenException(403, ''),
      );
      flow.bindEvents(stream);
      addTearDown(flow.dispose);
      await settle();
      expectWithdrawn(flow);
      expect(api.calls, 0);
      expect(stream.isConnected, false);
    },
  );
}

class Detail403Adapter implements HttpClientAdapter {
  int calls = 0;
  bool events = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    expectSync(o.method, 'GET');
    expectSync(
      o.uri.path,
      events
          ? '/api/v1/cs/organizations/1/seats/me/events'
          : '/api/v1/cs/organizations/1/sessions/4',
    );
    expectSync(o.queryParameters, {'workspace_id': '2'});
    calls++;
    return ResponseBody.fromString(
      '{"code":403,"msg":"synthetic-denied"}',
      403,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void _registerDioContract() {
  test(
    'real CsApi Dio detail403 on rated scoped event clears cached facts',
    () async {
      final adapter = await _prepareDioFixture();
      final completed = Completer<void>();
      final flow = seededFlow(
        CsApi(),
        changed: () {
          if (!completed.isCompleted) completed.complete();
        },
      );
      bindStream(flow, Stream.value(event('assignment.changed')));
      await completed.future.timeout(const Duration(seconds: 2));
      expect(adapter.calls, 1);
      expectWithdrawn(flow);
    },
  );
}

Future<Detail403Adapter> _prepareDioFixture() async {
  SharedPreferences.setMockInitialValues({});
  await StorageService.init();
  await StorageService.to.setString(Keys.currentUid, '9');
  String part(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  final token =
      '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}';
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'read'
            ? token
            : call.method == 'readAll'
            ? <String, String>{}
            : null,
      );
  final adapter = Detail403Adapter();
  HttpClient.adapterForTest = adapter;
  addTearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  return adapter;
}

void _registerLegalClosedRead() {
  test('scoped rated authorization success retains closed reading without history polling', () async {
    final api = RefusingDetailApi();
    final flow = seededFlow(api);
    api.result = flow.detail;
    bindStream(flow, Stream.value(event('seat.changed')));
    await settle();
    expect(api.calls, 1);
    expect(flow.readRevoked, false);
    expect(flow.machine.canDownload, true);
    expect(flow.machine.canSend, false);
    expect(flow.messages, hasLength(1));
    expect(flow.messageAssets, isNotEmpty);
    expect(flow.messageReadAt, isNotEmpty);
  });
}

void _registerRealStreamRefusal() {
  test(
    'production SSE open403 reaches scoped rated withdrawal through real Dio',
    () async {
      final adapter = await _prepareDioFixture();
      adapter.events = true;
      final completed = Completer<void>();
      final flow = seededFlow(
        CsApi(),
        changed: () {
          if (!completed.isCompleted) completed.complete();
        },
      );
      final stream = CsSeatEventsStream(orgId: '1', workspaceId: '2');
      flow.bindEvents(stream);
      addTearDown(flow.dispose);
      await completed.future.timeout(const Duration(seconds: 2));
      expect(adapter.calls, 1);
      expectWithdrawn(flow);
      expect(stream.isConnected, false);
    },
  );
}

void _registerEmptyResources() {
  for (final type in [
    'seat.changed',
    'assignment.changed',
    'session.changed',
  ]) {
    test(
      'unbound empty resource $type cannot trigger rated authority read',
      () async {
        final api = RefusingDetailApi();
        final flow = seededFlow(api);
        bindStream(flow, Stream.value(event(type, resource: '')));
        await settle();
        expect(api.calls, 0);
        expect(flow.readRevoked, false);
        expect(flow.messages, hasLength(1));
      },
    );
  }
}

void _registerResolvedWorkspace() {
  for (final ws in ['2', '9']) {
    test(
      'resolved SSE workspace $ws binds refusal to its actual request scope',
      () async {
        final flow = seededFlow(RefusingDetailApi());
        final stream = CsSeatEventsStream(
          orgId: '1',
          resolveWorkspaceId: () async => ws,
          opener: (org, workspace, {lastEventId = '', afterId = ''}) async =>
              throw const CsSseOpenException(403, ''),
        );
        flow.bindEvents(stream);
        addTearDown(flow.dispose);
        await settle();
        if (ws == '2') {
          expectWithdrawn(flow);
        } else {
          expect(flow.readRevoked, false);
          expect(flow.messages, hasLength(1));
        }
      },
    );
  }
}

void _registerLateDetailAfterRevoke() {
  test(
    'rated pending authority200 cannot revive after current SSE403',
    () async {
      final api = RefusingDetailApi()..pending = Completer<CsSessionDetail>();
      final snapshots = <bool>[];
      late CsSessionFlow flow;
      flow = seededFlow(api, changed: () => snapshots.add(flow.detail != null));
      final old = flow.detail!;
      final bytes = StreamController<List<int>>();
      bindStream(flow, bytes.stream);
      addTearDown(bytes.close);
      bytes.add(event('seat.changed'));
      await settle();
      expect(
        api.calls,
        1,
        reason: 'actual event handler holds the authority GET',
      );
      bytes.addError(const CsSseOpenException(403, ''));
      await settle();
      expectWithdrawn(flow);
      api.pending!.complete(old);
      await settle();
      expectWithdrawn(flow);
      expect(snapshots, isNotEmpty);
      expect(snapshots.every((hasPrivateDetail) => !hasPrivateDetail), true);
    },
  );
}
