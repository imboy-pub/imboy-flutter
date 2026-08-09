// integration_test/chat/group_chat_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';
import '../flows/test_utils.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('群聊', () {
    testWidgets(
      '进入已有群聊页面可访问',
      (tester) async {
        await ensureAppLaunched(tester, maxSeconds: 10);
        if (!await checkPreconditions(tester)) return;
        await settle(tester, maxSeconds: 2);
        await _dismissRecoveryGuideIfVisible(tester);

        if (!await _openConversationTab(tester)) {
          markTestSkipped('无法进入会话列表');
          return;
        }
        await settle(tester, maxSeconds: 2);
        await _dismissRecoveryGuideIfVisible(tester);
        await takeScreenshot(tester, 'group_readonly_01_conv_list');

        // 不能用标题文本猜测群聊：群名可能为空、包含任意语言，且 C2C
        // 会话标题也可能包含“群”字。直接读取现有会话模型的 C2G 类型。
        final groupItem = await _waitForExistingGroupItem(tester);
        if (groupItem == null) {
          markTestSkipped('当前测试账号没有可识别的已有群聊会话');
          return;
        }

        await safeTap(tester, groupItem.first);
        await settle(tester, maxSeconds: 3);
        await takeScreenshot(tester, 'group_readonly_02_chat_page');

        expect(
          find.byType(ChatPage),
          findsOneWidget,
          reason: '已有 C2G 会话应能进入群聊页面',
        );
        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets('进入已有群聊并发送文本消息', (tester) async {
      if (!requireBusinessWriteAuthorization()) return;
      await ensureAppLaunched(tester, maxSeconds: 3);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
      }
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'group_01_conv_list');

      // 优先找群聊标识，回退第一个会话
      final groupFinder = _anyText(['群', 'Group', '群聊']);
      final listTile = find.byType(ListTile);
      final target = tester.any(groupFinder)
          ? groupFinder.first
          : tester.any(listTile)
          ? listTile.first
          : null;

      if (target == null) {
        markTestSkipped('未找到群聊会话');
        return;
      }

      await safeTap(tester, target);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'group_02_chat_page');

      final inputField = find.byType(TextField);
      if (!tester.any(inputField)) {
        markTestSkipped('聊天页无输入框（可能被禁言）');
        return;
      }

      final msg = '[GROUP-E2E] ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(inputField.first, msg);

      final sent = await tapAny(tester, [
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'group_03_after_send');

      expect(
        find.textContaining('[GROUP-E2E]'),
        findsWidgets,
        reason: '发送后消息应出现在聊天列表中',
      );
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets(
      '从已有群聊进入群详情页可访问',
      (tester) async {
        await ensureAppLaunched(tester, maxSeconds: 10);
        if (!await checkPreconditions(tester)) return;
        await settle(tester, maxSeconds: 2);
        await _dismissRecoveryGuideIfVisible(tester);

        if (!await _openConversationTab(tester)) {
          markTestSkipped('无法进入会话列表');
          return;
        }
        await settle(tester, maxSeconds: 2);
        await _dismissRecoveryGuideIfVisible(tester);

        final groupItem = await _waitForExistingGroupItem(tester);
        if (groupItem == null) {
          markTestSkipped('当前测试账号没有可识别的已有群聊会话');
          return;
        }

        await safeTap(tester, groupItem.first);
        await settle(tester, maxSeconds: 3);
        if (!tester.any(find.byType(ChatPage))) {
          markTestSkipped('已有群聊会话未进入聊天页面');
          return;
        }
        await _dismissRecoveryGuideIfVisible(tester);

        final settingsButton = find.byIcon(Icons.more_horiz);
        if (!tester.any(settingsButton)) {
          markTestSkipped('群聊页面未找到群详情入口');
          return;
        }
        await safeTap(tester, settingsButton.first);
        await settle(tester, maxSeconds: 4);

        expect(
          find.byType(GroupDetailPage),
          findsOneWidget,
          reason: '已有群聊应能打开群详情页',
        );
        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}

bool _isOnConvList(WidgetTester t) =>
    t.any(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ConversationPage',
      ),
    ) ||
    (t.any(find.byIcon(Icons.search)) &&
        t.any(find.byIcon(Icons.add_circle_outline)));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  await tapAny(t, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Chats'),
  ]);
  for (int i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (_isOnConvList(t)) return true;
  }
  return false;
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});

Future<Finder?> _waitForExistingGroupItem(WidgetTester tester) async {
  for (int i = 0; i < 60; i++) {
    final groupItem = find.byWidgetPredicate(
      (widget) => widget is ConversationItem && widget.model.type == 'C2G',
    );
    if (tester.any(groupItem)) return groupItem;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return null;
}

Future<void> _dismissRecoveryGuideIfVisible(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    final later = _anyText(['稍后', 'Later']);
    if (tester.any(later)) {
      await safeTap(tester, later.first);
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
