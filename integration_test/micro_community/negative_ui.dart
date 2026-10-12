import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/common_bar.dart' show GlassBackButton;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';

import '../flows/test_utils.dart' show settle, waitForMainShell;
import 'negative_phase.dart';
import 'owned_ui_launch.dart';

const negativeChannelId = String.fromEnvironment('MC_CHANNEL_ID');
const negativeGroupId = String.fromEnvironment('MC_DISCUSSION_GROUP_ID');
const negativeChannelName = String.fromEnvironment('MC_CHANNEL_NAME');

class NegativeUi {
  NegativeUi(this.tester);
  final WidgetTester tester;

  Future<void> waitVisible(Finder finder, {int attempts = 80}) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      await negativePump(tester);
      if (tester.any(finder)) break;
    }
    expect(finder, findsOneWidget, reason: 'required real UI control absent');
  }

  Future<void> launchAndOpenContent() async {
    await launchOwnedUi(tester);
    expect(await waitForMainShell(tester), isTrue);
    await openDiscoveredContent();
    final channel = tester
        .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
        .channel;
    expect(channel.isManaged, isFalse);
    expect(channel.isPaid, isFalse);
    expect(channel.isSubscribed, isFalse);
    expect(find.byType(ChatPage), findsNothing);
  }

  Future<void> openDiscoveredContent() async {
    final channelTab = find.byKey(const Key('tab_channel'));
    expect(channelTab, findsOneWidget);
    await tester.tap(channelTab);
    await settle(tester);
    expect(find.byType(ChannelListPage), findsOneWidget);
    final discover = find.descendant(
      of: find.byType(ChannelListPage),
      matching: find.byWidgetPredicate(
        (w) =>
            w is CupertinoButton &&
            w.child is Icon &&
            (w.child as Icon).icon == CupertinoIcons.search,
      ),
    );
    expect(discover, findsOneWidget);
    await tester.tap(discover);
    final result = find.descendant(
      of: find.byType(ChannelDiscoverPage),
      matching: find.byWidgetPredicate(
        (w) => w is Text && w.data == negativeChannelName,
      ),
    );
    await waitVisible(result);
    await tester.ensureVisible(result);
    await tester.tap(result);
    await waitVisible(find.byType(ChannelHeaderBar));
    final channel = tester
        .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
        .channel;
    expect(channel.id.toString(), negativeChannelId);
    expect(find.byType(ChatPage), findsNothing);
  }

  Future<void> subscribeAndJoin() async {
    final subscribe = find.descendant(
      of: find.byType(ChannelHeaderBar),
      matching: find.text(t.channel.subscribe),
    );
    expect(subscribe, findsOneWidget);
    await tester.ensureVisible(subscribe);
    await tester.tap(subscribe);
    await settle(tester);
    expect(
      tester
          .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
          .channel
          .isSubscribed,
      isTrue,
    );
    expect(find.byType(ChatPage), findsNothing);
    await tapDiscussionConfirmation();
    await waitChat();
  }

  Future<void> tapDiscussionConfirmation() async {
    final join = find.byKey(const Key('mc_discussion_join'));
    await waitVisible(join);
    await tester.ensureVisible(join);
    await tester.tap(join);
    await settle(tester);
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    await tester.tap(find.byKey(const Key('mc_join_confirm')));
    await settle(tester);
  }

  Future<void> waitChat() async {
    await waitVisible(find.byType(ChatPage));
    final chat = tester.widget<ChatPage>(find.byType(ChatPage));
    expect(chat.peerId, negativeGroupId);
    expect(chat.type, 'C2G');
  }

  Future<void> warmMembersAndReturn() async {
    final settings = find.descendant(
      of: find.byType(ChatPage),
      matching: find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == t.common.chatSettings,
      ),
    );
    expect(settings, findsOneWidget);
    await tester.tap(settings);
    await waitVisible(find.byType(GroupDetailPage));
    expect(
      tester.widget<GroupDetailPage>(find.byType(GroupDetailPage)).groupId,
      negativeGroupId,
    );
    await settle(tester);
    await backFrom(find.byType(GroupDetailPage));
    await waitChat();
    await returnToContent();
  }

  Future<void> backFrom(Finder page) async {
    final back = find.descendant(
      of: page,
      matching: find.byType(GlassBackButton),
    );
    expect(back, findsOneWidget, reason: 'real back control required');
    await tester.tap(back);
    await settle(tester);
  }

  Future<String> returnToContent() async {
    await backFrom(find.byType(ChatPage));
    var path = 'chat_back';
    if (!tester.any(find.byType(ChannelDetailPage))) {
      expect(await waitForMainShell(tester), isTrue);
      await openDiscoveredContent();
      path = 'chat_back_then_tab_discover';
    }
    expect(find.byType(ChannelDetailPage), findsOneWidget);
    await restoreHeader();
    expect(
      tester
          .widget<ChannelHeaderBar>(find.byType(ChannelHeaderBar))
          .channel
          .id
          .toString(),
      negativeChannelId,
    );
    expect(find.byType(ChatPage), findsNothing);
    return path;
  }

  Future<void> restoreHeader() async {
    final view = find.descendant(
      of: find.byType(ChannelDetailPage),
      matching: find.byType(CustomScrollView),
    );
    await waitVisible(view);
    final controller = tester.widget<CustomScrollView>(view).controller;
    expect(controller, isNotNull);
    final outer = find.descendant(
      of: view,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && identical(w.controller, controller),
      ),
    );
    expect(outer, findsOneWidget);
    final header = find.byType(ChannelHeaderBar);
    for (var attempt = 0; attempt < 10 && !tester.any(header); attempt++) {
      final rect = tester.getRect(view);
      await tester.dragFrom(
        Offset(rect.center.dx, rect.top + 24),
        const Offset(0, 300),
      );
      await negativePump(tester);
    }
    await settle(tester);
    expect(header, findsOneWidget);
  }

  Future<void> sendMarker(String marker) async {
    await waitChat();
    final input = find.byKey(const Key('chat_message_input'));
    expect(input, findsOneWidget);
    await tester.enterText(input, marker);
    // 发送按钮显隐走 300ms debounce Timer（chat_input.dart
    // _handleTextControllerChange），单次 pump 不等定时器，必须轮询等待。
    final send = find.byKey(const ValueKey('send_button'));
    await waitVisible(send);
    await tester.tap(send);
    await settle(tester);
  }

  Finder message(String id) => find.descendant(
    of: find.byType(ChatPage),
    matching: find.byWidgetPredicate(
      (w) => w is ChatMessageItem && w.message.id == id,
    ),
  );

  void expectAbsent(String id) {
    expect(
      message(id),
      findsNothing,
      reason: 'new canary rendered in revoked UI',
    );
    expect(find.textContaining(id, findRichText: true), findsNothing);
  }
}
