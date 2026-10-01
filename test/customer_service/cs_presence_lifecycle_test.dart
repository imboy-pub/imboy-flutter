import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/public.dart';

class _PendingApi extends CsApi {
  final heartbeat = Completer<CsPresence>();
  final manual = Completer<CsPresence>();
  var calls = 0;

  @override
  Future<CsPresence> seatHeartbeat(String orgId, {String workspaceId = ''}) {
    calls++;
    return heartbeat.future;
  }

  @override
  Future<CsPresence> setSeatPresence(
    String orgId,
    String? manualStatus, {
    String workspaceId = '',
  }) {
    calls++;
    return manual.future;
  }
}

CsPresence _online() => CsPresence(
  status: CsPresenceStatus.online,
  enabled: true,
  maxConcurrent: 3,
  activeCount: 0,
  lastHeartbeatAt: 100,
);

void main() {
  test('restarting cannot accept a previous manual status response', () async {
    final api = _PendingApi();
    var notifications = 0;
    final controller = CsPresenceController(
      csApi: api,
      orgId: '1',
      workspaceId: '2',
      onPresenceChanged: () => notifications++,
    );
    final pending = controller.setManualStatus('away');
    controller.stop();
    controller.start();
    addTearDown(controller.stop);
    api.manual.complete(_online());
    await pending;
    expect(controller.lastPresence, isNull);
    expect(notifications, 0);
    api.heartbeat.complete(_online());
    await Future<void>.delayed(Duration.zero);
    expect(controller.lastPresence?.status, CsPresenceStatus.online);
    expect(notifications, 1);
  });

  for (final fails in [false, true]) {
    test(
      'stopped heartbeat ignores late ${fails ? 'failure' : 'success'}',
      () async {
        final api = _PendingApi();
        var notifications = 0;
        final controller = CsPresenceController(
          csApi: api,
          orgId: '1',
          workspaceId: '2',
          onPresenceChanged: () => notifications++,
        );
        final pending = controller.beat();
        controller.stop();
        if (fails) {
          api.heartbeat.completeError(StateError('disconnected'));
        } else {
          api.heartbeat.complete(_online());
        }
        await pending;
        expect(controller.lastPresence, isNull);
        expect(notifications, 0);
        await controller.beat();
        expect(api.calls, 1);
      },
    );
  }

  test('stopped resume cannot refresh another workspace', () async {
    final api = _PendingApi();
    var resyncs = 0;
    final controller = CsPresenceController(
      csApi: api,
      orgId: '1',
      workspaceId: '2',
      onResync: () async => resyncs++,
    );
    final pending = controller.onAppLifecycleStateChanged('resumed');
    controller.stop();
    api.heartbeat.complete(_online());
    await pending;
    await controller.onAppLifecycleStateChanged('resumed');
    expect(resyncs, 0);
    expect(api.calls, 1);
  });

  test(
    'stopped manual status ignores late response and future actions',
    () async {
      final api = _PendingApi();
      var notifications = 0;
      final controller = CsPresenceController(
        csApi: api,
        orgId: '1',
        workspaceId: '2',
        onPresenceChanged: () => notifications++,
      );
      final pending = controller.setManualStatus('away');
      controller.stop();
      api.manual.complete(_online());
      await pending;
      expect(controller.lastPresence, isNull);
      expect(notifications, 0);
      await controller.setManualStatus(null);
      expect(api.calls, 1);
    },
  );
}
