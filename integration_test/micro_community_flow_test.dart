// Real Android UI journey. Requires an isolated pre-seeded unsubscribed free channel,
// bound group and matching account; missing resources fail, never auto-skip.
// MC-AC-21 handoff: an isolated non-admin account starts unsubscribed to a free,
// discoverable channel. Seed a bound group and a short visible essence post with
// MC_POST_TAG, MC_POST_QUERY and MC_EXPECTED_BODY; all identifiers are explicit.
// MC-AC-22 handoff remains separate: the executor must provide real Android UI
// network impairment/recovery, membership revocation and backend/DB oracles.
// This journey does not simulate weak networks or claim revocation coverage.
// Execution requires physical-device handoff and is left to the main owner.
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/ui/common_bar.dart' show GlassBackButton;
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/channel_message_item.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';

import 'micro_community/owned_ui_launch.dart';
import 'flows/test_utils.dart'
    show
        FlowConfig,
        waitForEntryState,
        isOnWelcomePage,
        leaveWelcomePage,
        isOnLoginPage,
        performLogin,
        waitForMainShell,
        settle,
        takeScreenshot;

const name = String.fromEnvironment('MC_CHANNEL_NAME');
const query = String.fromEnvironment('MC_POST_QUERY');
const groupId = String.fromEnvironment('MC_DISCUSSION_GROUP_ID');
const channelId = String.fromEnvironment('MC_CHANNEL_ID');
const tag = String.fromEnvironment('MC_POST_TAG');
const expectedBody = String.fromEnvironment('MC_EXPECTED_BODY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: explicit subscribe -> discussion join -> group chat -> scoped essence/tag/search',
    _runJourney,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _runJourney(WidgetTester tester) async {
  await _requireAndroidFixture(tester);
  await _launchAndAuthenticate(tester);
  await _openFixtureViaDiscovery(tester);
  await _assertFreshFixture(tester);
  await _subscribeExplicitly(tester);
  await _joinAndVerifyChat(tester);
  await _returnToContent(tester);
  await _filterAndVerifyScopedPosts(tester);
}

Future<void> _openFixtureViaDiscovery(WidgetTester tester) async {
  final channelTab = find.byKey(const Key('tab_channel'));
  expect(channelTab, findsOneWidget);
  await tester.tap(channelTab);
  await settle(tester);
  expect(find.byType(ChannelListPage), findsOneWidget);
  final discover = find.descendant(
    of: find.byType(ChannelListPage),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is CupertinoButton &&
          widget.child is Icon &&
          (widget.child as Icon).icon == CupertinoIcons.search,
    ),
  );
  expect(discover, findsOneWidget, reason: 'real discover control required');
  await tester.tap(discover);
  await settle(tester);
  expect(find.byType(ChannelDiscoverPage), findsOneWidget);
  await _waitForDiscoverFixture(tester);
  final result = _discoverFixture();
  await tester.ensureVisible(result);
  await tester.tap(result);
  await settle(tester);
}

Finder _discoverFixture() => find.descendant(
  of: find.byType(ChannelDiscoverPage),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == name,
  ),
);

Future<void> _waitForDiscoverFixture(WidgetTester tester) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (tester.any(_discoverFixture())) break;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  expect(
    _discoverFixture(),
    findsOneWidget,
    reason: 'unsubscribed fixture must appear in real discovery listing',
  );
}

Future<void> _requireAndroidFixture(WidgetTester tester) async {
  expect(
    Platform.isAndroid,
    isTrue,
    reason: 'Android required, desktop and iOS rejected',
  );
  final device = await DeviceInfoPlugin().androidInfo;
  expect(
    device.isPhysicalDevice,
    isTrue,
    reason: 'simulator is not acceptance evidence',
  );
  expect(name, isNotEmpty);
  expect(query, isNotEmpty);
  expect(groupId, matches(RegExp(r'^[1-9][0-9]*$')));
  expect(channelId, matches(RegExp(r'^[1-9][0-9]*$')));
  expect(tag, isNotEmpty);
  expect(expectedBody, isNotEmpty);
  expect(expectedBody.contains(query), isTrue);
  expect(
    FlowConfig.appEnv,
    isNotEmpty,
    reason: 'explicit isolated environment required',
  );
  expect(FlowConfig.isApprovedProbeTarget(FlowConfig.apiBaseUrl), isTrue);
}

Future<void> _launchAndAuthenticate(WidgetTester tester) async {
  await launchOwnedUi(tester);
  await settle(tester);
  expect(await waitForEntryState(tester), isTrue);
  if (isOnWelcomePage(tester)) {
    expect(await leaveWelcomePage(tester), isTrue);
    await settle(tester);
  }
  if (isOnLoginPage(tester)) {
    expect(FlowConfig.testPhone, isNotEmpty);
    expect(FlowConfig.testPassword, isNotEmpty);
    expect(
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      ),
      isTrue,
    );
  }
  expect(await waitForMainShell(tester), isTrue);
}

Future<void> _assertFreshFixture(WidgetTester tester) async {
  expect(find.byType(ChannelDetailPage), findsOneWidget);
  expect(
    find.byType(ChatPage),
    findsNothing,
    reason: 'opening content must not automatically join/open discussion',
  );
  final before = tester
      .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
      .channel;
  expect(before.id.toString(), channelId);
  expect(
    before.isManaged,
    isFalse,
    reason: 'fixture must exercise subscriber rights',
  );
  expect(before.isPaid, isFalse, reason: 'free isolated fixture required');
  expect(
    before.isSubscribed,
    isFalse,
    reason: 'pre-subscribed fixture is not MC-AC-21',
  );
}

Future<void> _subscribeExplicitly(WidgetTester tester) async {
  final subscribe = find.descendant(
    of: find.byType(ChannelHeaderBar),
    matching: find.text(t.channel.subscribe),
  );
  await tester.ensureVisible(subscribe.first);
  await tester.tap(subscribe.first);
  await settle(tester);
  expect(
    tester
        .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
        .channel
        .isSubscribed,
    isTrue,
  );
  expect(
    find.byType(ChatPage),
    findsNothing,
    reason: 'subscribe must not automatically join/open discussion',
  );
}

Future<void> _joinAndVerifyChat(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('mc_discussion_join')));
  await tester.tap(find.byKey(const Key('mc_discussion_join')));
  await settle(tester);
  expect(find.byType(CupertinoAlertDialog), findsOneWidget);
  expect(
    find.byType(ChatPage),
    findsNothing,
    reason: 'join requires explicit confirmation',
  );
  await tester.tap(find.byKey(const Key('mc_join_confirm')));
  await settle(tester);
  expect(find.byType(ChatPage), findsOneWidget);
  final chat = tester.widget<ChatPage>(find.byType(ChatPage));
  expect(chat.peerId, groupId);
  expect(chat.type, 'C2G');
  await takeScreenshot(tester, 'mc_android_discussion_chat');
}

Future<void> _returnToContent(WidgetTester tester) async {
  final back = find.descendant(
    of: find.byType(ChatPage),
    matching: find.byType(GlassBackButton),
  );
  expect(
    back,
    findsOneWidget,
    reason: 'real chat back control must be present',
  );
  await tester.tap(back);
  await settle(tester);
  expect(find.byType(ChannelDetailPage), findsOneWidget);
  await _restoreContentHeader(tester);
  expect(
    tester
        .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
        .channel
        .id
        .toString(),
    channelId,
  );
}

Future<void> _restoreContentHeader(WidgetTester tester) async {
  final page = find.byType(ChannelDetailPage);
  final outerView = find.descendant(
    of: page,
    matching: find.byType(CustomScrollView),
  );
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (tester.any(outerView)) break;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  expect(
    outerView,
    findsOneWidget,
    reason: 'real content scroll view required',
  );
  final controller = tester.widget<CustomScrollView>(outerView).controller;
  expect(controller, isNotNull);
  final outerScroll = find.descendant(
    of: outerView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && identical(widget.controller, controller),
    ),
  );
  expect(outerScroll, findsOneWidget, reason: 'outer content scroll required');
  final header = find.descendant(
    of: page,
    matching: find.byType(ChannelHeaderBar),
  );
  for (var attempt = 0; attempt < 10 && !tester.any(header); attempt++) {
    final viewport = tester.getRect(outerView);
    await tester.dragFrom(
      Offset(viewport.center.dx, viewport.top + 24),
      const Offset(0, 300),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
  await settle(tester);
  expect(header, findsOneWidget, reason: 'real content header must be visible');
}

Future<void> _filterAndVerifyScopedPosts(WidgetTester tester) async {
  final essence = find.descendant(
    of: find.byKey(const Key('mc_essence_filter')),
    matching: find.text(t.channel.essence),
  );
  await tester.ensureVisible(essence);
  await tester.tap(essence);
  await settle(tester);
  await tester.enterText(find.byKey(const Key('mc_tag_filter')), tag);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester);
  await tester.enterText(find.byKey(const Key('mc_post_search')), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await settle(tester);
  final body = find.descendant(
    of: find.byType(ChannelMessageItem),
    matching: find.textContaining(expectedBody, findRichText: true),
  );
  expect(
    body,
    findsWidgets,
    reason: 'seeded body must render inside scoped post cards, not merely the search input',
  );
  final cards = tester.widgetList<ChannelMessageItem>(
    find.byType(ChannelMessageItem),
  );
  expect(cards, isNotEmpty);
  for (final card in cards) {
    expect(card.message.channelId.toString(), channelId);
    expect(card.message.isEssence, isTrue);
    expect(card.message.tags, contains(tag));
  }
  await takeScreenshot(tester, 'mc_android_essence_tag_search');
}
