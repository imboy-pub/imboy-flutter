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
import 'package:imboy/page/channel/channel_message_item.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';

import 'flows/app_launcher.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: explicit subscribe -> discussion join -> group chat -> scoped essence/tag/search',
    (tester) async {
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
      const name = String.fromEnvironment('MC_CHANNEL_NAME');
      const query = String.fromEnvironment('MC_POST_QUERY');
      const groupId = String.fromEnvironment('MC_DISCUSSION_GROUP_ID');
      const channelId = String.fromEnvironment('MC_CHANNEL_ID');
      const tag = String.fromEnvironment('MC_POST_TAG');
      const expectedBody = String.fromEnvironment('MC_EXPECTED_BODY');
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
      await ensureAppLaunched(tester);
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
      await tester.tap(find.text(t.channel.title).first);
      await settle(tester);
      await tester.tap(find.text(name).first);
      await settle(tester);
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
      expect(
        tester
            .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
            .channel
            .id
            .toString(),
        channelId,
      );
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
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
