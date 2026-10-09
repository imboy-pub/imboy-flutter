// Run live and reconnect in separate owned leases/APKs/account databases.
// Root owns real OS VIEW intents and this run's reverse removal/restoration.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/service/websocket.dart';

import 'flows/test_utils.dart' show flowLog, settle;
import 'micro_community/negative_access.dart';
import 'micro_community/negative_evidence.dart';
import 'micro_community/negative_phase.dart';
import 'micro_community/negative_ui.dart';
import 'micro_community/owned_session.dart';

const _mode = String.fromEnvironment('MC_OWNED_NEGATIVE_MODE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(establishOwnedAndroidSession);
  testWidgets(
    'Android MC22 owned $_mode entitlement revocation',
    _run,
    timeout: const Timeout(Duration(minutes: 9)),
  );
}

Future<void> _run(WidgetTester tester) async {
  final phase = NegativePhase(_mode);
  final ui = NegativeUi(tester);
  final access = NegativeAccess();
  NegativeEvidence? evidence;
  try {
    await ui.launchAndOpenContent();
    access.bindChannelClient();
    evidence = await NegativeEvidence.capture();
    await phase.wait(tester, 'boot');
    await _warm(ui, phase, access, evidence);
    if (_mode == 'live') {
      await _live(ui, phase, access, evidence);
    } else {
      await _reconnect(ui, phase, access, evidence);
    }
    await evidence.sameSession();
    await phase.wait(tester, 'verified');
    flowLog('MC22 mode=$_mode phase=verified');
  } finally {
    access.close();
    await evidence?.close();
  }
}

Future<void> _warm(
  NegativeUi ui,
  NegativePhase phase,
  NegativeAccess access,
  NegativeEvidence evidence,
) async {
  await ui.subscribeAndJoin();
  await ui.warmMembersAndReturn();
  await evidence.expectWarmCache(ui);
  await access.beforeAccess();
  expect(find.byType(ChatPage), findsNothing);
  await phase.ack('joined');
  // Root now sends a real VIEW; no test navigation can enter this ChatPage.
  await ui.waitChat();
  expect(await NegativeAccess.httpReachable(), isTrue);
  expect(WebSocketService.to.status, SocketStatus.connected);
  await evidence.sameSession();
  await phase.ack('warm');
  await phase.wait(ui.tester, 'before_emitted');
  await evidence.beforeReceived(ui, phase);
  await phase.ack('before_received');
}

Future<void> _live(
  NegativeUi ui,
  NegativePhase phase,
  NegativeAccess access,
  NegativeEvidence evidence,
) async {
  await phase.wait(ui.tester, 'after_emitted');
  await evidence.observeRevoked(ui, phase);
  await access.denyAccess();
  await ui.sendMarker(phase.rejectedMarker);
  await _observeReject(ui, evidence, phase.rejectedMarker);
  final actualId = await evidence.rejectState(ui, phase.rejectedMarker);
  final path = await ui.returnToContent();
  flowLog('MC22 mode=live return_path=$path');
  await phase.ack('chat_denied', actualId: actualId);
  await _oldIntent(ui, phase, access, evidence);
  await _cacheGate(ui, phase, access, evidence);
}

Future<void> _oldIntent(
  NegativeUi ui,
  NegativePhase phase,
  NegativeAccess access,
  NegativeEvidence evidence,
) async {
  // Root sends the exact same pre-revoke OS VIEW after this round's barrier.
  await ui.waitChat();
  await access.denyAccess();
  await access.joinDeniedWithoutUi();
  await evidence.absent(ui, phase.afterId);
  await evidence.absent(ui, phase.offlineId);
  await evidence.sameSession();
  await phase.ack('old_intent_denied');
}

Future<void> _cacheGate(
  NegativeUi ui,
  NegativePhase phase,
  NegativeAccess access,
  NegativeEvidence evidence,
) async {
  final path = await ui.returnToContent();
  flowLog('MC22 mode=live cache_return_path=$path');
  final join = find.byKey(const Key('mc_discussion_join'));
  if (ui.tester.any(join)) {
    final prior = access.bindingResponses;
    await ui.tapDiscussionConfirmation();
    await access.waitBindingDenied(ui, prior);
    expect(find.byType(ChatPage), findsNothing);
    expect(find.text(t.common.loadError), findsWidgets);
    await access.joinDeniedWithoutUi();
    flowLog(
      'MC22 mode=live cache_gate=fresh_binding_denied server_join=non_ui_probe',
    );
  } else {
    expect(
      ui.tester
          .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
          .channel
          .isSubscribed,
      isFalse,
    );
    expect(join, findsNothing);
    await access.joinDeniedWithoutUi();
    flowLog(
      'MC22 mode=live cache_gate=button_removed server_join=non_ui_probe',
    );
  }
  await evidence.sameSession();
  await evidence.absent(ui, phase.afterId);
  await phase.ack('cache_denied');
}

Future<void> _reconnect(
  NegativeUi ui,
  NegativePhase phase,
  NegativeAccess access,
  NegativeEvidence evidence,
) async {
  await phase.wait(ui.tester, 'link_drop_requested');
  expect(
    await NegativeAccess.httpReachable(),
    isFalse,
    reason: 'actual owned HTTP failure required after reverse removal',
  );
  await _waitSocket(ui, SocketStatus.disconnected);
  expect(await NegativeAccess.httpReachable(), isFalse);
  await evidence.sameSession();
  await phase.ack('disconnected');
  await phase.wait(ui.tester, 'offline_prepared');
  expect(WebSocketService.to.status, SocketStatus.disconnected);
  await ui.sendMarker(phase.rejectedMarker);
  final queuedId = await evidence.queuedState(ui, phase.rejectedMarker);
  await phase.ack('queue_ready');
  await phase.wait(ui.tester, 'link_restored');
  await _waitSocket(ui, SocketStatus.connected);
  expect(await NegativeAccess.httpReachable(), isTrue);
  await evidence.sameSession();
  final path = await ui.returnToContent();
  flowLog('MC22 mode=reconnect return_path=$path');
  await phase.ack('reconnected');
  await _oldIntent(ui, phase, access, evidence);
  await access.offlineDenied(phase.offlineId);
  await evidence.absent(ui, phase.offlineId);
  await phase.ack('offline_denied');
  await _observeReject(ui, evidence, phase.rejectedMarker);
  expect(await evidence.rejectState(ui, phase.rejectedMarker), queuedId);
  await evidence.observeRevoked(ui, phase);
  await phase.ack('queued_denied', actualId: queuedId);
}

Future<void> _waitSocket(NegativeUi ui, SocketStatus required) async {
  for (var attempt = 0; attempt < 240; attempt++) {
    await negativePump(ui.tester);
    if (WebSocketService.to.status == required) break;
  }
  expect(
    WebSocketService.to.status,
    required,
    reason: 'real production WebSocket state transition required',
  );
}

Future<void> _observeReject(
  NegativeUi ui,
  NegativeEvidence evidence,
  String marker,
) async {
  for (var tick = 0; tick < 20; tick++) {
    await negativePump(ui.tester);
    await evidence.rejectState(ui, marker);
  }
  await settle(ui.tester);
}
