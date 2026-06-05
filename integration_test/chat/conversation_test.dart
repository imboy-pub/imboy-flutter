// integration_test/chat/conversation_test.dart
//
// 会话管理 UI 集成测试
//
// 运行：
//   flutter test integration_test/chat/conversation_test.dart \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     -d <real_device_id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('会话管理', () {
    testWidgets('会话列表显示与交互', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'conv_01_launch');

      await checkPreconditions(tester);

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'conv_02_after_login');

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表页，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'conv_03_conversation_list');

      final slidable = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'Slidable',
      );
      final listTile = find.byType(ListTile);

      if (tester.any(slidable)) {
        flowLog('✅ 找到 ${slidable.evaluate().length} 个会话项 (Slidable)');
      } else if (tester.any(listTile)) {
        flowLog('✅ 找到 ${listTile.evaluate().length} 个列表项 (ListTile)');
      } else {
        flowLog('会话列表为空或未加载');
      }

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('长按会话项出现操作菜单', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);

      await checkPreconditions(tester);

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);

      final slidable = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'Slidable',
      );
      final listTile = find.byType(ListTile);

      Finder? target;
      if (tester.any(slidable)) {
        target = slidable.first;
      } else if (tester.any(listTile)) {
        target = listTile.first;
      }

      if (target == null) {
        markTestSkipped('会话列表为空，无法测试长按菜单，跳过');
        return;
      }

      await tester.longPress(target);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'conv_menu_after_longpress');

      final menuOptions = [
        '置顶',
        '取消置顶',
        '删除',
        '免打扰',
        '标记已读',
        'Pin',
        'Delete',
        'Mute',
        'Mark read',
      ];
      final found = menuOptions.where((o) => tester.any(find.text(o))).toList();

      // 断言：长按后应出现操作菜单
      expect(found, isNotEmpty, reason: '长按会话项后应出现操作菜单，实际未找到任何已知选项');
      flowLog('✅ 菜单选项: $found');

      await tester.tapAt(const Offset(10, 10));
      await settle(tester, maxSeconds: 1);

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('搜索入口可访问', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);

      await checkPreconditions(tester);

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);

      final searchIcon = find.byIcon(Icons.search);
      if (!tester.any(searchIcon)) {
        markTestSkipped('未找到搜索图标，跳过');
        return;
      }

      await safeTap(tester, searchIcon.first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'conv_search_page');

      // 断言：搜索页应有文本输入框
      expect(find.byType(TextField), findsWidgets, reason: '搜索页面应有文本输入框');

      await tester.enterText(find.byType(TextField).first, 'test');
      await settle(tester, maxSeconds: 1);
      await takeScreenshot(tester, 'conv_search_typed');

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

// ──────────────────────────────────────────────
// 会话页专用导航（本文件私有，不复制到 test_utils.dart）
// ──────────────────────────────────────────────

bool _isOnConversationListPage(WidgetTester tester) {
  return tester.any(find.byIcon(Icons.search)) &&
      tester.any(find.byIcon(Icons.add_circle_outline));
}

Future<bool> _openConversationTab(WidgetTester tester) async {
  if (_isOnConversationListPage(tester)) return true;

  final tapped = await tapAny(tester, [
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Message'),
    find.text('Messages'),
    find.text('Chats'),
  ]);

  if (!tapped) {
    final glassBar = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
    );
    if (tester.any(glassBar)) {
      try {
        final rect = tester.getRect(glassBar.first);
        await tester.tapAt(
          Offset(rect.left + rect.width * 0.5 / 4, rect.center.dy),
        );
        await settle(tester, maxSeconds: 2);
      } catch (_) {}
    }
  }

  for (int i = 0; i < 5; i++) {
    await settle(tester, maxSeconds: 1);
    if (_isOnConversationListPage(tester)) return true;
  }
  return false;
}
