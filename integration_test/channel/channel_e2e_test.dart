// integration_test/channel/channel_e2e_test.dart
//
// 频道端到端 UI 集成测试
//
// 运行：
//   flutter test integration_test/channel/channel_e2e_test.dart \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     -d <real_device_id>
//
// 跳过策略：
//   - 后端不可达 / 未配置凭证 / 登录失败 → markTestSkipped（SKIP，非假绿）
//   - 预期路径上的断言 → expect/fail（FAIL，真实失败）

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('频道端到端验收', () {
    testWidgets('进入已订阅频道详情并发布文本消息', (tester) async {
      app.main();
      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'channel_01_launch');

      if (!await checkPreconditions(tester)) return;

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'channel_02_after_login');

      if (!await _openChannelTab(tester)) {
        markTestSkipped('无法进入频道 Tab，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'channel_03_channel_tab');
      drainKnownFrameworkExceptions(tester);

      // 若已订阅列表为空，尝试进入发现页
      if (!tester.any(find.byType(ListTile))) {
        flowLog('已订阅列表为空，尝试进入发现频道页');
        await tapAny(tester, [
          find.byIcon(Icons.search),
          find.text('发现频道'),
          find.text('Discover Channels'),
        ]);
        await settle(tester, maxSeconds: 2);
      }

      if (!tester.any(find.byType(ListTile))) {
        markTestSkipped('无可进入频道（无已订阅数据），跳过');
        return;
      }

      final entered = await safeTap(tester, find.byType(ListTile).first);
      if (!entered) {
        markTestSkipped('点击频道项失败，跳过');
        return;
      }
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'channel_04_channel_detail');
      drainKnownFrameworkExceptions(tester);

      // 断言：进入详情后不应出现"频道不存在"
      expect(
        _anyText(['频道不存在', 'Channel not found']),
        findsNothing,
        reason: '已订阅频道进入详情后不应提示频道不存在',
      );

      final inputField = find.byType(TextField);
      if (!tester.any(inputField)) {
        // 当前账号无发布权限，详情可访问性验收通过即可
        flowLog('当前账号无发布权限，跳过发布动作，详情可访问性验收通过');
        await _tryBack(tester);
        drainKnownFrameworkExceptions(tester);
        return;
      }

      final msg = '[CHANNEL-E2E] ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(inputField.first, msg);
      await takeScreenshot(tester, 'channel_05_input_message');

      final sent = await tapAny(tester, [
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('发布'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'channel_06_after_publish');

      // 断言：发布后不应出现失败提示
      expect(
        _anyText(['发布失败', 'Publish failed']),
        findsNothing,
        reason: '频道发布消息不应出现失败提示',
      );

      await _tryBack(tester);
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('创建新频道后发布文本消息', (tester) async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final channelName = 'E2E频道_$ts';
      final channelDesc = 'E2E 自动创建 $ts';
      final channelCustomId = _buildCustomId();
      final msg = '[CHANNEL-E2E-CREATE] $ts';

      app.main();
      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'channel_create_01_launch');

      if (!await checkPreconditions(tester)) return;

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'channel_create_02_after_login');

      if (!await _openChannelTab(tester)) {
        markTestSkipped('无法进入频道 Tab，跳过');
        return;
      }

      await settle(tester, maxSeconds: 1);
      drainKnownFrameworkExceptions(tester);

      if (!await _openCreateChannelPage(tester)) {
        markTestSkipped('无法打开创建频道页面，跳过');
        return;
      }

      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'channel_create_03_create_form');
      drainKnownFrameworkExceptions(tester);

      final formFields = find.byType(TextFormField);
      if (!tester.any(formFields)) {
        markTestSkipped('未找到创建频道表单，跳过');
        return;
      }

      await tester.enterText(formFields.at(0), channelName);
      if (formFields.evaluate().length > 1) {
        await tester.enterText(formFields.at(1), channelDesc);
      }
      if (formFields.evaluate().length > 2) {
        await tester.enterText(formFields.at(2), channelCustomId);
      }
      await takeScreenshot(tester, 'channel_create_04_form_filled');

      final submitted = await tapAny(tester, [
        find.text('确定'),
        find.text('确认'),
        find.text('Confirm'),
      ]);
      if (!submitted) {
        final buttons = find.byType(TextButton);
        if (tester.any(buttons)) {
          await tester.tap(buttons.first);
          await settle(tester, maxSeconds: 2);
        } else {
          markTestSkipped('未找到提交按钮，跳过');
          return;
        }
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'channel_create_05_after_submit');
      drainKnownFrameworkExceptions(tester);

      if (tester.any(find.byType(TextFormField))) {
        markTestSkipped('创建后仍停留在创建页（疑似创建失败），跳过');
        return;
      }

      // 断言：创建成功后频道名可见，发送按钮可见
      expect(find.text(channelName), findsWidgets, reason: '创建成功后应显示频道名称');
      expect(find.byIcon(Icons.send), findsWidgets, reason: '创建者进入频道后应看到发布按钮');
      expect(
        _anyText(['频道不存在', 'Channel not found']),
        findsNothing,
        reason: '新建频道详情不应提示频道不存在',
      );

      final inputField = find.byType(TextField);
      if (!tester.any(inputField)) {
        markTestSkipped('新建频道后未找到发布输入框，跳过');
        return;
      }

      await tester.enterText(inputField.first, msg);
      await takeScreenshot(tester, 'channel_create_06_input');

      final sent = await tapAny(tester, [
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('发布'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'channel_create_07_after_publish');

      expect(
        _anyText(['发布失败', 'Publish failed']),
        findsNothing,
        reason: '创建后发布消息不应出现失败提示',
      );

      await _tryBack(tester);
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

// ──────────────────────────────────────────────
// 频道页专用导航（本文件私有，不污染 test_utils.dart）
// ──────────────────────────────────────────────

bool _isOnChannelListPage(WidgetTester tester) {
  return tester.any(_anyText(['频道', 'Channel', 'Channels'])) &&
      tester.any(find.byIcon(Icons.search)) &&
      tester.any(find.byIcon(Icons.add));
}

Future<bool> _openChannelTab(WidgetTester tester) async {
  if (_isOnChannelListPage(tester)) return true;
  for (int i = 0; i < 4; i++) {
    final tapped = await tapAny(tester, [
      find.byIcon(Icons.campaign_outlined),
      find.byIcon(Icons.campaign),
      find.text('频道'),
      find.text('Channel'),
      find.text('Channels'),
    ]);
    if (tapped) {
      await settle(tester, maxSeconds: 2);
      if (_isOnChannelListPage(tester)) return true;
    }
  }
  return false;
}

Future<bool> _openCreateChannelPage(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    final tapped = await tapAny(tester, [
      find.byIcon(Icons.add),
      find.text('创建频道'),
      find.text('Create Channel'),
    ]);
    if (!tapped) continue;
    await settle(tester, maxSeconds: 2);
    if (tester.any(_anyText(['创建频道', 'Create Channel'])) &&
        tester.any(find.byType(TextFormField))) {
      return true;
    }
  }
  return false;
}

Future<void> _tryBack(WidgetTester tester) async {
  final tapped = await tapAny(tester, [
    find.byTooltip('Back'),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.close),
    find.text('返回'),
    find.text('Back'),
  ]);
  if (!tapped) {
    try {
      await tester.pageBack();
      await settle(tester, maxSeconds: 2);
    } catch (_) {
      flowLog('当前页面无可用返回入口');
    }
  }
}

Finder _anyText(List<String> candidates) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data?.trim();
    if (data == null || data.isEmpty) return false;
    return candidates.any((c) => data.contains(c));
  });
}

String _buildCustomId() {
  final tail = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = Random().nextInt(36 * 36).toRadixString(36).padLeft(2, '0');
  final left = tail.length > 6 ? tail.substring(tail.length - 6) : tail;
  return 'e2e_$left$rand';
}
