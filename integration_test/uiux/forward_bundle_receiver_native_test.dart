import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show ScrollToBottom;
import 'package:integration_test/integration_test.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../chat/support/c2c_journey_support.dart';
import '../enterprise/macos_storage_isolation.dart';
import '../flows/test_utils.dart';
import '../helpers/chat_multi_bundle_history.dart';
import '../helpers/chat_multi_driver.dart';
import '../micro_community/owned_ui_launch.dart';

const _viewer = '123613243079133184';
const _sender = '123613243007830016';
const _storage = 'viewer_uiux_20261114_1794632987';
const _nonce = String.fromEnvironment('CHAT_MULTI_RUN_NONCE');
const _locationOnly = bool.fromEnvironment('UIUX_LOCATION_RECEIVER');
const _receiverLabel = _locationOnly
    ? 'Owned Mac receives and UI acknowledges the exact location receipt'
    : 'Owned Mac receives, renders and UI acknowledges exact bundle';

Future<void> _restoreViewer(WidgetTester tester) async {
  expect(const bool.fromEnvironment('IMBOY_TEST_ISOLATED'), isTrue);
  expect(const String.fromEnvironment('APP_ENV'), 'local');
  final api = Uri.parse(const String.fromEnvironment('API_BASE_URL_OVERRIDE'));
  expect(api.scheme, 'http');
  expect(api.host, '127.0.0.1');
  expect(api.userInfo, isEmpty);
  expect(
    const bool.fromEnvironment('IMBOY_LOCAL_MAP_REQUESTS_ALLOWED'),
    isFalse,
  );
  expect(const String.fromEnvironment('TEST_EXPECTED_UID'), _viewer);
  expect(const String.fromEnvironment('PEER_UID'), _sender);
  expect(const String.fromEnvironment('H2_STORAGE_TAG'), _storage);
  expect(const bool.fromEnvironment('H2_RESTORE_STORAGE'), isTrue);
  expect(const String.fromEnvironment('CHAT_MULTI_EXPECT_E2EE'), 'true');
  expect(
    const bool.fromEnvironment('IMBOY_LOCAL_EXTERNAL_SERVICES_DISABLED'),
    isTrue,
  );
  final root = await tester.runAsync(
    () => isolateH2MacosStorage(_storage, _viewer, restore: true),
  );
  expect(root, isNotNull);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await AppInitializer.dispose();
      await SqliteService.to.close();
    });
  });
  await launchOwnedUi(tester);
  var ready = false;
  for (var i = 0; i < 180 && !ready; i++) {
    final shell = find.byType(ChatShellBootstrap);
    if (tester.any(shell)) {
      await ProviderScope.containerOf(tester.element(shell))
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.personal);
    }
    ready = await waitForMainShell(tester, maxAttempts: 1);
  }
  expect(ready, isTrue);
  expect(UserRepoLocal.to.isLoggedIn, isTrue);
  expect(UserRepoLocal.to.currentUid, _viewer);
  await tester.runAsync(
    () =>
        E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm)
            .timeout(const Duration(seconds: 90)),
  );
}

Future<void> _verifyDetails(
  WidgetTester tester,
  Finder card,
  Map<String, dynamic> snapshot,
  List<String> markers,
) async {
  final entries = historyBundleEntries(snapshot);
  expect(snapshot['bundle_version'], 1);
  expect(snapshot['title'], isA<String>());
  expect('${snapshot['title']}', isNotEmpty);
  expect(entries, hasLength(4));
  expect([
    for (final entry in entries.take(3)) (entry['payload'] as Map)['text'],
  ], markers);
  expect(entries.last['msg_type'], 'image');
  final details = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'HistoryBundleDetailPage',
  );
  await tapFinderWithEffect(
    tester,
    find.descendant(
      of: card,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget.key != null &&
            widget.key.toString().contains('history_bundle_bubble_'),
      ),
    ),
    journey: 'OWNED-BUNDLE-RECEIVER',
    targetDescription: 'received bundle card',
    effectCheck: () => tester.any(details),
  );
  expect(await waitForFinder(tester, details, maxSeconds: 10), isTrue);
  expect(find.textContaining('${snapshot['title']}'), findsWidgets);
  final offsets = <double>[];
  for (final marker in markers) {
    final text = find.textContaining(marker, findRichText: true);
    expect(text, findsOneWidget);
    offsets.add(tester.getTopLeft(text).dy);
  }
  expect(offsets[0] < offsets[1] && offsets[1] < offsets[2], isTrue);
  final thumb = find.byKey(const ValueKey('bundle_detail_thumb_3'));
  expect(thumb, findsOneWidget);
  await tester.ensureVisible(thumb);
  var decoded = false;
  for (var i = 0; i < 120 && !decoded; i++) {
    final pixels = find.descendant(of: thumb, matching: find.byType(RawImage));
    if (tester.any(pixels)) {
      final image = tester.renderObject<RenderImage>(pixels.first).image;
      decoded = image != null && image.width > 0 && image.height > 0;
    }
    if (!decoded) await tester.pump(const Duration(milliseconds: 500));
  }
  expect(
    decoded,
    isTrue,
    reason: 'Authorized bundle image must decode, not show placeholder',
  );
  await popTopPage(tester, details);
  expect(
    await waitForFinder(tester, find.byType(ChatPage), maxSeconds: 10),
    isTrue,
  );
}

Future<bool> _waitForVisibleBundle(
  WidgetTester tester,
  Finder chat,
  Finder card,
  String marker,
) async {
  final latest = find
      .descendant(
        of: find.descendant(of: chat, matching: find.byType(ScrollToBottom)),
        matching: find.byType(FloatingActionButton),
      )
      .hitTestable();
  final deadline = DateTime.now().add(const Duration(seconds: 240));
  var taps = 0;
  while (DateTime.now().isBefore(deadline)) {
    if (tester.any(card.hitTestable())) return true;
    if (taps < 8 && tester.any(latest)) {
      expect(latest, findsOneWidget);
      await tester.tap(latest);
      taps++;
      expect(UserRepoLocal.to.currentUid, _viewer);
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  _diagnoseBundle(tester, chat, marker, taps);
  await takeScreenshot(tester, 'w3k_wait_timeout');
  return false;
}

void _diagnoseBundle(
  WidgetTester tester,
  Finder chat,
  String marker,
  int taps,
) {
  try {
    final mounted = find.descendant(
      of: chat,
      matching: find.byType(HistoryBundleMessageBuilder),
    );
    final mountedIds = tester
        .widgetList<HistoryBundleMessageBuilder>(mounted)
        .map((builder) => builder.message.id)
        .toSet();
    final container = ProviderScope.containerOf(tester.element(chat));
    final messages = container
        .read(chatProvider.notifier)
        .chatService
        ?.messages;
    final matches = [
      if (messages != null)
        for (final message in messages)
          if (message.authorId == _sender &&
              historyBundleEntries(message.metadata ?? {}).any(
                (entry) =>
                    entry['payload'] is Map &&
                    (entry['payload'] as Map)['text'] == marker,
              ))
            {
              'id': message.id,
              'status': message.status?.name,
              'mounted': mountedIds.contains(message.id),
            },
    ];
    debugPrintSynchronously(
      '[UIUX-BUNDLE-RECEIVER] timeout scroll_taps=$taps decoded_nonce_matches=$matches',
    );
  } on Object catch (error) {
    debugPrintSynchronously(
      '[UIUX-BUNDLE-RECEIVER] timeout diagnostic_error_type=${error.runtimeType}',
    );
  }
}

core.Message _assertLocationReceipt(
  WidgetTester tester,
  Finder chat,
  Finder card,
  String tag,
) {
  final message = tester.widget<ChatMessageItem>(card).message;
  final data = message.metadata ?? {};
  expect(data['_e2ee_failed'], isNot(true));
  expect(message.status, isIn(settledStatuses));
  expect(data['title'], isA<String>());
  expect('${data['title']}', isNotEmpty);
  expect(
    find.descendant(of: card, matching: find.text('${data['title']}')),
    findsOneWidget,
  );
  for (final field in ['latitude', 'longitude']) {
    final value = double.tryParse('${data[field]}');
    expect(value?.isFinite, isTrue, reason: '$field must survive decryption');
    expect(value?.abs(), lessThanOrEqualTo(field == 'latitude' ? 90 : 180));
  }
  final container = ProviderScope.containerOf(tester.element(chat));
  final markers =
      (container.read(chatProvider.notifier).chatService?.messages ??
              const <core.Message>[])
          .whereType<core.TextMessage>()
          .where((m) => m.authorId == _sender && m.text == 'UX01-$tag')
          .toList();
  expect(markers, hasLength(1));
  expect(markers.single.createdAt?.isBefore(message.createdAt!), isTrue);
  return message;
}

Future<void> _verifyLocationReceipt(WidgetTester tester, Finder chat) async {
  const id = String.fromEnvironment('UX01_LOCATION_MESSAGE_ID');
  const tag = String.fromEnvironment('UX01_RUN_TAG');
  expect(id, matches(RegExp(r'^[a-z0-9]{10,128}$')));
  expect(tag, matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
  final card = find.byWidgetPredicate(
    (w) =>
        w is ChatMessageItem &&
        w.message.id == id &&
        w.message.authorId == _sender &&
        w.message.metadata?['msg_type'] == 'location',
  );
  expect(await waitForFinder(tester, card, maxSeconds: 240), isTrue);
  await tester.ensureVisible(card);
  await settle(tester, maxSeconds: 1);
  expect(card.hitTestable(), findsOneWidget);
  final message = _assertLocationReceipt(tester, chat, card, tag);
  final image = find.descendant(
    of: card,
    matching: find.byWidgetPredicate(
      (w) =>
          w is RawImage &&
          (w.image?.width ?? 0) > 1 &&
          (w.image?.height ?? 0) > 1,
    ),
  );
  expect(
    await waitForFinder(tester, image, maxSeconds: 90),
    isTrue,
    reason:
        'The recipient must decode the authorized encrypted location preview',
  );
  final receipt = '[UIUX-LOCATION-ACK]-$tag-${message.id}';
  await sendTextViaInput(tester, chat, receipt);
  final sent = await waitSent(tester, receipt, maxSeconds: 30);
  expect(sent?.authorId, _viewer);
  expect(sent?.status, isIn(settledStatuses));
  debugPrintSynchronously(
    '[UIUX-LOCATION-RECEIVER] verified:$tag:${message.id}',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(_receiverLabel, (tester) async {
    expect(_nonce, matches(RegExp(r'^[A-Za-z0-9_-]{1,80}$')));
    expect(requireBusinessWriteAuthorization(), isTrue);
    await _restoreViewer(tester);
    final did = await tester.runAsync(() => DeviceExt.did);
    expect(did, isNotEmpty);
    final history = ChatMultiBundleHistory(
      senderUid: _sender,
      recipientUid: _viewer,
      fetchPage: (query) async {
        final page = await MsgApi().history(
          chatType: 'c2c',
          peerId: _sender,
          afterSeq: int.parse('${query['after_seq']}'),
          limit: int.parse('${query['limit']}'),
          did: did!,
        );
        if (page == null) {
          throw StateError('Owned receiver history request failed');
        }
        return {'code': 0, 'payload': page};
      },
    );
    await tester.runAsync(history.captureBaseline);
    final chat = await pushChatPage(
      tester,
      type: 'C2C',
      peerId: _sender,
      peerTitle: 'uiux_editor_20261114',
    );
    if (_locationOnly) {
      await _verifyLocationReceipt(tester, chat);
      return;
    }
    final markers = [for (var i = 1; i <= 3; i++) '[W3K-BND]-t$i-$_nonce'];
    // Root starts the sender only after this exact nonce-bound baseline/ready marker.
    debugPrintSynchronously('[UIUX-BUNDLE-RECEIVER] ready:$_nonce');
    final card = find.byWidgetPredicate(
      (widget) =>
          widget is HistoryBundleMessageBuilder &&
          widget.message.authorId == _sender &&
          historyBundleEntries(widget.message.metadata ?? {}).any(
            (entry) =>
                entry['payload'] is Map &&
                (entry['payload'] as Map)['text'] == markers.first,
          ),
    );
    expect(
      await _waitForVisibleBundle(tester, chat, card, markers.first),
      isTrue,
    );
    expect(card, findsOneWidget);
    final message = tester.widget<HistoryBundleMessageBuilder>(card).message;
    expect(message.id, isNotEmpty);
    final snapshot = Map<String, dynamic>.from(message.metadata ?? {});
    await _verifyDetails(tester, card, snapshot, markers);
    final row = await tester.runAsync(
      () => history.waitForBundle(messageId: message.id),
    );
    expect(row, isNotNull);
    expect(
      bundleHistoryPlaintext(row!, markers: markers, expectEncrypted: true),
      isNull,
    );
    final receipt = bundleUiReceipt(_nonce, message.id, snapshot);
    await sendTextViaInput(tester, chat, receipt);
    final sent = await waitSent(tester, receipt, maxSeconds: 30);
    expect(sent?.authorId, _viewer);
    expect(sent?.status, isIn(settledStatuses));
    debugPrintSynchronously(
      '[UIUX-BUNDLE-RECEIVER] verified:$_nonce:${message.id}',
    );
  }, timeout: const Timeout(Duration(minutes: 12)));
}
