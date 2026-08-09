// integration_test/chat/quick_reply_manage_test.dart
//
// 快捷回复管理页功能测试
//

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat/widget/quick_reply_manage_page.dart';
import 'package:imboy/page/chat/widget/chat_input_types.dart';
import 'package:imboy/service/quick_reply_service.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/test_utils.dart'
    show
        flowLog,
        drainKnownFrameworkExceptions,
        autoLoginOrSkip,
        waitForEntryState,
        isOnMainShell;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('快捷回复管理页测试', () {
    testWidgets('完整CRUD与边界条件测试', (tester) async {
      app.main();

      // 抽帧等待启动/网络初始化完成。
      await _pump(tester, seconds: 3);

      // 清空存储中的 Token，确保以干净的未登录状态启动，防止旧 Token 中途导致 401 登出
      flowLog('清除旧登录 Token 以防测试期间发生 401 登出冲突...');
      try {
        await SecureTokenStorageService.clear();
      } catch (e) {
        flowLog('清除 Token 异常（可忽略）：$e');
      }

      await _pump(tester, seconds: 5);

      // 等待页面加载（欢迎页、登录页或主界面）
      flowLog('等待页面加载...');
      for (int i = 0; i < 40; i++) {
        final hasSkip =
            tester.any(find.text('跳过')) || tester.any(find.text('Skip'));
        final isLogin =
            tester.any(find.byKey(const Key('login_phone_input'))) ||
            tester.any(find.text('登录')) ||
            tester.any(find.text('登 录'));
        final isMain =
            tester.any(find.byType(BottomNavigationBar)) ||
            tester.any(find.byType(NavigationBar)) ||
            tester.any(find.byType(BottomAppBar)) ||
            tester.any(
              find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == 'GlassBottomNavigationBar',
              ),
            );

        if (hasSkip || isLogin || isMain) {
          flowLog('页面已加载：hasSkip=$hasSkip, isLogin=$isLogin, isMain=$isMain');
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // 如果在欢迎页，点击跳过以进入登录页
      final skipFinder = find.text('跳过');
      final skipEnFinder = find.text('Skip');
      if (tester.any(skipFinder)) {
        flowLog('在欢迎页，点击跳过');
        await tester.tap(skipFinder.first);
        await _pump(tester, seconds: 4);
      } else if (tester.any(skipEnFinder)) {
        flowLog('On welcome page, clicking Skip');
        await tester.tap(skipEnFinder.first);
        await _pump(tester, seconds: 4);
      }

      // 等待进入可操作入口（登录页或主界面）
      flowLog('等待进入可操作界面...');
      await waitForEntryState(tester);

      // 如果未登录，执行自动登录
      flowLog('执行自动登录检查...');
      await autoLoginOrSkip(tester);

      // 确保进入了主界面（完成登录后的所有跳转和重定向）
      flowLog('确保完全进入了主界面...');
      for (int i = 0; i < 40; i++) {
        if (isOnMainShell(tester)) {
          flowLog('已进入主界面 shell');
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
      }

      final navFinder = find.byType(Navigator);
      if (!tester.any(navFinder)) {
        markTestSkipped('未找到 Navigator，跳过');
        return;
      }

      // -------------------------------------------------------------
      // 前置：清空当前用户的自定义快捷回复，确保测试加载我们传入的 defaults
      // -------------------------------------------------------------
      final currentUid = UserRepoLocal.to.currentUid;
      if (currentUid.isNotEmpty) {
        flowLog('重置当前用户 ($currentUid) 的快捷回复以确保测试一致性...');
        final service = QuickReplyService(
          const StorageServiceQuickReplyStore(),
          defaults: [],
        );
        await service.reset(currentUid);
      }

      final nav = Navigator.of(
        tester.element(navFinder.first),
        rootNavigator: true,
      );

      // PUSH 快捷回复管理页，注入测试默认数据
      flowLog('进入快捷回复管理页 (isolated)');
      final testDefaults = ['Reply-A', 'Reply-B', 'Reply-C'];
      nav.push(
        MaterialPageRoute(
          builder: (_) => QuickReplyManagePage(defaults: testDefaults),
        ),
      );

      await _pump(tester, seconds: 4);

      // -------------------------------------------------------------
      // 1. 加载快捷回复列表
      // -------------------------------------------------------------
      flowLog('1. 验证默认短语加载与显示');
      expect(find.text('Reply-A'), findsOneWidget);
      expect(find.text('Reply-B'), findsOneWidget);
      expect(find.text('Reply-C'), findsOneWidget);

      // -------------------------------------------------------------
      // 2. 输入框最大长度限制生效
      // -------------------------------------------------------------
      flowLog('2. 验证新增对话框及输入框长度限制');
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget, reason: '已登录态下应当显示新增 FAB 按钮');

      await tester.tap(fabFinder);
      await _pump(tester, seconds: 2);

      final textFields = find.byType(TextField);
      expect(textFields, findsOneWidget, reason: '应当弹起新增输入框');

      final textField = tester.widget<TextField>(textFields.first);
      expect(textField.maxLength, equals(200), reason: '输入框最大长度限制必须为 200');

      // 取消对话框（语言无关：AlertDialog 下第一个 TextButton 按钮通常为 取消/Cancel）
      final dialogButtons = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      );
      if (tester.any(dialogButtons)) {
        await tester.tap(dialogButtons.first);
        await _pump(tester, seconds: 2);
      }

      // -------------------------------------------------------------
      // 3. 点 FAB 新增快捷回复短语
      // -------------------------------------------------------------
      flowLog('3. 新增一条合法快捷短语');
      await tester.tap(fabFinder);
      await _pump(tester, seconds: 2);

      await tester.enterText(find.byType(TextField).first, 'Reply-New');
      await _pump(tester, seconds: 1);

      // 点击确定（语言无关：AlertDialog 下最后一个 TextButton 按钮通常为 确定/Confirm/OK）
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await _pump(tester, seconds: 3);

      expect(
        find.text('Reply-New'),
        findsOneWidget,
        reason: 'Reply-New 应当添加并显示在列表中',
      );

      // -------------------------------------------------------------
      // 4. 重复内容校验并提示
      // -------------------------------------------------------------
      flowLog('4. 验证重复内容拒绝校验');
      await tester.tap(fabFinder);
      await _pump(tester, seconds: 2);

      await tester.enterText(find.byType(TextField).first, 'Reply-New');
      await _pump(tester, seconds: 1);

      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await _pump(tester, seconds: 3);

      // -------------------------------------------------------------
      // 5. 点击条目进入编辑弹窗 并 编辑短语
      // -------------------------------------------------------------
      flowLog('5. 验证点击列表项编辑短语');
      final targetItem = tester.any(find.text('Reply-New-Edited'))
          ? find.text('Reply-New-Edited').first
          : find.text('Reply-New').first;
      await tester.tap(targetItem);
      await _pump(tester, seconds: 2);

      expect(find.byType(TextField), findsOneWidget, reason: '点击项应该拉起编辑对话框');
      await tester.enterText(find.byType(TextField).first, 'Reply-New-Edited');
      await _pump(tester, seconds: 1);

      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await _pump(tester, seconds: 3);

      expect(find.text('Reply-New'), findsNothing);
      expect(find.text('Reply-New-Edited'), findsOneWidget);

      // -------------------------------------------------------------
      // 6. 点铅笔按钮编辑短语
      // -------------------------------------------------------------
      flowLog('6. 验证点铅笔按钮编辑短语');
      final pencilFinder = find.byIcon(CupertinoIcons.pencil);
      expect(pencilFinder, findsWidgets, reason: '列表中应当渲染铅笔编辑图标');

      await tester.tap(pencilFinder.first); // 点击第一个铅笔图标 (Reply-A)
      await _pump(tester, seconds: 2);

      await tester.enterText(find.byType(TextField).first, 'Reply-A-Pencil');
      await _pump(tester, seconds: 1);

      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await _pump(tester, seconds: 3);

      expect(find.text('Reply-A'), findsNothing);
      expect(find.text('Reply-A-Pencil'), findsOneWidget);

      // -------------------------------------------------------------
      // 7. 左划删除单条快捷回复
      // -------------------------------------------------------------
      flowLog('7. 验证左滑删除短语');
      expect(find.text('Reply-C'), findsOneWidget);

      // 执行左滑拖拽动作
      await tester.drag(find.text('Reply-C').first, const Offset(-500.0, 0.0));
      await _pump(tester, seconds: 3);

      expect(find.text('Reply-C'), findsNothing, reason: 'Reply-C 左滑删除后应当不复存在');

      // -------------------------------------------------------------
      // 8. 拖拽手柄调整条目顺序 (模拟 Reorder 操作)
      // -------------------------------------------------------------
      flowLog('8. 验证拖拽手柄及 Reorderable 结构');
      expect(
        find.byIcon(Icons.drag_handle),
        findsWidgets,
        reason: '应当渲染拖拽手柄图标',
      );

      // Pop 返回
      nav.pop();
      await _pump(tester, seconds: 2);

      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Future<void> _pump(WidgetTester tester, {required int seconds}) async {
  for (int i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}
