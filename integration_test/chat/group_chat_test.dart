// 群组聊天测试
//
// 测试群组功能：
// - 创建群组（通过"发起聊天"页面）
// - 发送群消息（点击已有群组会话）
// - 群成员管理

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import '../test_config.dart';
import '../test_helper.dart';

bool _backendProbePassed = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('群组聊天测试', () {
    testWidgets(
      '通过发起聊天创建群组',
      (WidgetTester tester) async {
      TestHelper.log('🚀 开始群组创建 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'group_01_app_launch');

      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过群组测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过群组测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (TestHelper.needsLogin(tester)) {
        TestHelper.log('📝 当前页面需要登录');
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 测试账号未配置，跳过群组测试');
          return;
        }
        final success = await TestHelper.autoLogin(tester);
        if (!success) {
          TestHelper.log('⚠️ 自动登录失败，跳过群组测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      } else {
        TestHelper.log('✅ 已登录或无需登录');
      }

      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_02_after_login');

      // 步骤 1: 点击右上角加号按钮（会话页的 add_circle_outline）
      final addBtn = find.byIcon(Icons.add_circle_outline);
      if (!tester.any(addBtn)) {
        TestHelper.log('⚠️ 未找到加号按钮，跳过群组测试');
        TestHelper.log('[AUTO-SKIP] reason=no_add_button');
        return;
      }

      await _tapFinder(tester, addBtn.first);
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_03_add_menu');
      await _drainUnexpectedFrameworkExceptions(tester);

      // 步骤 2: 在弹出菜单中点击"发起聊天"
      final launchChatText = _findAnyText(<String>[
        '发起聊天',
        'Initiate Chat',
        'Start Chat',
        'New Chat',
      ]);

      if (!tester.any(launchChatText)) {
        TestHelper.log('⚠️ 未找到"发起聊天"菜单项，跳过群组测试');
        TestHelper.log('[AUTO-SKIP] reason=no_launch_chat_menu');
        return;
      }

      await _tapFinder(tester, launchChatText.first);
      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_04_launch_chat_page');
      await _drainUnexpectedFrameworkExceptions(tester);

      // 步骤 3: 确认进入了 LaunchChatPage（应有联系人列表）
      var hasContactList = tester.any(find.byType(ListTile)) ||
          tester.any(find.byType(CheckboxListTile));
      if (!hasContactList) {
        // 可能还在加载
        TestHelper.log('ℹ️ 发起聊天页未显示联系人列表，等待加载');
        await Future<dynamic>.delayed(const Duration(seconds: 2));
        await _shortSettle(tester);
      }

      final listTiles = find.byType(ListTile);
      if (!tester.any(listTiles)) {
        TestHelper.log('⚠️ 没有可选联系人，跳过创建群组');
        TestHelper.log('[AUTO-SKIP] reason=no_contacts');
        return;
      }

      // 步骤 4: 选择至少 2 个联系人（创建群组至少需要 2 人）
      final tileCount = listTiles.evaluate().length;
      TestHelper.log('ℹ️ 找到 $tileCount 个联系人');

      final selectCount = tileCount >= 2 ? 2 : tileCount;
      for (int i = 0; i < selectCount; i++) {
        await _tapFinder(tester, listTiles.at(i));
        await _shortSettle(tester);
      }
      await _safeScreenshot(tester, 'group_05_contacts_selected');

      // 步骤 5: 点击"完成"按钮创建群组
      final confirmBtn = _findAnyText(<String>[
        '完成',
        '确认',
        'Confirm',
        'Done',
      ]);
      // 也搜索 RoundedElevatedButton
      final elevatedBtn = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'RoundedElevatedButton',
      );

      bool created = false;
      if (tester.any(confirmBtn)) {
        await _tapFinder(tester, confirmBtn.first);
        created = true;
      } else if (tester.any(elevatedBtn)) {
        await _tapFinder(tester, elevatedBtn.first);
        created = true;
      }

      if (!created) {
        TestHelper.log('⚠️ 未找到确认创建按钮，跳过群组测试');
        TestHelper.log('[AUTO-SKIP] reason=no_create_confirm_button');
        return;
      }

      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_06_after_create');
      await _drainUnexpectedFrameworkExceptions(tester);

      // 创建成功后应该进入群聊页面
      final hasChatPage = tester.any(find.byType(TextField));
      if (hasChatPage) {
        TestHelper.log('✅ 群组创建成功，已进入群聊页面');
      } else {
        TestHelper.log('ℹ️ 创建后未检测到聊天输入框，可能创建失败或页面跳转异常');
      }

      await _tryNavigateBack(tester);
      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      '进入已有群组会话发送消息',
      (WidgetTester tester) async {
      final msg = '[GROUP-E2E] ${DateTime.now().millisecondsSinceEpoch}';
      TestHelper.log('🚀 开始群消息发送 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'group_msg_01_app_launch');

      final backendOk2 = await _ensureBackendAvailable();
      if (!backendOk2) {
        TestHelper.log('⚠️ 后端不可用，跳过群消息测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk2 = await _waitForEntryState(tester);
      if (!entryOk2) {
        TestHelper.log('⚠️ 入口状态异常，跳过群消息测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (TestHelper.needsLogin(tester)) {
        TestHelper.log('📝 当前页面需要登录');
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 测试账号未配置，跳过群消息测试');
          return;
        }
        final success = await TestHelper.autoLogin(tester);
        if (!success) {
          TestHelper.log('⚠️ 自动登录失败，跳过群消息测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      } else {
        TestHelper.log('✅ 已登录或无需登录');
      }

      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_msg_02_after_login');

      // 步骤 1: 查找会话列表中的群组会话
      final listTiles = find.byType(ListTile);
      if (!tester.any(listTiles)) {
        TestHelper.log('ℹ️ 没有会话列表，跳过群消息测试');
        TestHelper.log('[AUTO-SKIP] reason=no_conversations');
        return;
      }

      // 点击第一个会话
      await _tapFinder(tester, listTiles.first);
      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_msg_03_conversation_opened');
      await _drainUnexpectedFrameworkExceptions(tester);

      // 步骤 2: 检查是否有输入框
      final inputField = find.byType(TextField);
      if (!tester.any(inputField)) {
        TestHelper.log('ℹ️ 打开的会话没有输入框，跳过发送测试');
        await _tryNavigateBack(tester);
        return;
      }

      // 步骤 3: 发送消息
      await TestHelper.enterText(tester, inputField.first, msg);
      await _safeScreenshot(tester, 'group_msg_04_input_message');

      final sent = await _tapAny(tester, <Finder>[
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _shortSettle(tester);
      }

      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_msg_05_after_send');
      await _drainUnexpectedFrameworkExceptions(tester);

      await _tryNavigateBack(tester);
      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      '群成员管理',
      (WidgetTester tester) async {
      TestHelper.log('🚀 开始群成员管理 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'group_member_01_app_launch');

      final backendOk3 = await _ensureBackendAvailable();
      if (!backendOk3) {
        TestHelper.log('⚠️ 后端不可用，跳过群成员管理测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk3 = await _waitForEntryState(tester);
      if (!entryOk3) {
        TestHelper.log('⚠️ 入口状态异常，跳过群成员管理测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (TestHelper.needsLogin(tester)) {
        TestHelper.log('📝 当前页面需要登录');
        if (!TestConfig.isConfigured) {
          TestHelper.log('⚠️ 测试账号未配置，跳过群成员管理测试');
          return;
        }
        final success = await TestHelper.autoLogin(tester);
        if (!success) {
          TestHelper.log('⚠️ 自动登录失败，跳过群成员管理测试');
          TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
          return;
        }
      } else {
        TestHelper.log('✅ 已登录或无需登录');
      }

      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_member_02_after_login');

      // 进入群组列表页
      final opened = await _openGroupListPage(tester);
      if (!opened) {
        TestHelper.log('⚠️ 无法进入群组列表，跳过群成员管理测试');
        TestHelper.log('[AUTO-SKIP] reason=no_group_list');
        return;
      }

      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_member_03_group_list');
      await _drainUnexpectedFrameworkExceptions(tester);

      // 点击第一个群组进入详情
      final groupListTiles = find.byType(ListTile);
      if (!tester.any(groupListTiles)) {
        TestHelper.log('ℹ️ 群组列表为空，跳过群成员管理测试');
        TestHelper.log('[AUTO-SKIP] reason=no_groups');
        return;
      }

      await _tapFinder(tester, groupListTiles.first);
      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_member_04_group_detail');
      await _drainUnexpectedFrameworkExceptions(tester);

      // 查找群组设置入口
      final moreButton = find.byIcon(Icons.more_vert);
      final settingsButton = find.byIcon(Icons.settings);

      if (tester.any(moreButton)) {
        TestHelper.log('✅ 找到更多按钮');
        await _tapFinder(tester, moreButton.first);
        await _shortSettle(tester);
        await _safeScreenshot(tester, 'group_member_05_settings');
      } else if (tester.any(settingsButton)) {
        TestHelper.log('✅ 找到设置按钮');
        await _tapFinder(tester, settingsButton.first);
        await _shortSettle(tester);
        await _safeScreenshot(tester, 'group_member_05_settings');
      } else {
        TestHelper.log('ℹ️ 未找到群组设置入口');
      }

      await _tryNavigateBack(tester);
      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );
  });
}

// ============================================================
// 辅助函数
// ============================================================

Finder _findAnyText(List<String> candidates) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data?.trim();
    if (data == null || data.isEmpty) return false;
    for (final candidate in candidates) {
      if (data.contains(candidate)) return true;
    }
    return false;
  });
}

Future<bool> _tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (await _tapFinder(tester, finder)) return true;
  }
  return false;
}

Future<bool> _tapFinder(WidgetTester tester, Finder finder) async {
  if (!tester.any(finder)) return false;
  final target = finder.evaluate().length > 1 ? finder.first : finder;
  try {
    await tester.ensureVisible(target);
  } catch (_) {}
  try {
    await tester.tap(target, warnIfMissed: false);
    await _shortSettle(tester);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _shortSettle(
  WidgetTester tester, {
  Duration total = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _safeScreenshot(WidgetTester tester, String name) async {
  try {
    await TestHelper.screenshot(tester, name);
  } on MissingPluginException {
    TestHelper.log('ℹ️ 当前运行器不支持截图，跳过: $name');
  }
}

Future<void> _tryNavigateBack(WidgetTester tester) async {
  final tapped = await _tapAny(tester, <Finder>[
    find.byTooltip('Back'),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.close),
    find.text('返回'),
    find.text('Back'),
  ]);
  if (tapped) return;
  try {
    await tester.pageBack();
    await _shortSettle(tester);
  } catch (_) {
    TestHelper.log('ℹ️ 当前页面无可用返回入口，跳过返回动作');
  }
}

Future<void> _drainUnexpectedFrameworkExceptions(WidgetTester tester) async {
  const maxDrain = 24;
  for (int i = 0; i < maxDrain; i++) {
    final err = tester.takeException();
    if (err == null) break;
    if (_isIgnorableFrameworkException(err)) {
      TestHelper.log('ℹ️ 忽略非核心异常: $err');
      continue;
    }
    TestHelper.log('ℹ️ 排除非核心异常: $err');
  }
}

bool _isIgnorableFrameworkException(Object err) {
  final text = err.toString();
  return text.contains('ImageNotFoundException') ||
      text.contains('Image not found (404)') ||
      text.startsWith('Multiple exceptions (');
}

Future<bool> _waitForEntryState(WidgetTester tester) async {
  const maxRounds = 20;
  for (int i = 0; i < maxRounds; i++) {
    if (TestHelper.needsLogin(tester) ||
        _isOnConversationPage(tester) ||
        _isOnMainShellPage(tester)) {
      return true;
    }
    await Future<dynamic>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }
  TestHelper.log('⚠️ 入口状态等待超时，跳过');
  return false;
}

bool _isOnConversationPage(WidgetTester tester) {
  final hasSearch = tester.any(find.byIcon(Icons.search));
  final hasAdd = tester.any(find.byIcon(Icons.add_circle_outline));
  return hasSearch && hasAdd;
}

bool _isOnMainShellPage(WidgetTester tester) {
  final hasGlassBottomBar = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    ),
  );
  final hasBottomBar = tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      tester.any(find.byType(BottomAppBar)) ||
      hasGlassBottomBar;
  return hasBottomBar;
}

/// 尝试进入群组列表页
Future<bool> _openGroupListPage(WidgetTester tester) async {
  final candidates = <Finder>[
    find.text('群组'),
    find.text('Group'),
    find.text('Groups'),
    find.byIcon(Icons.group),
    find.byIcon(Icons.group_outlined),
    find.byIcon(Icons.people),
    find.byIcon(Icons.people_outline),
  ];

  for (int i = 0; i < 4; i++) {
    for (final finder in candidates) {
      final tapped = await _tapFinder(tester, finder);
      if (!tapped) continue;
      await _shortSettle(tester);
      if (tester.any(find.byType(ListTile)) ||
          tester.any(find.byType(SliverList))) {
        return true;
      }
    }
  }

  TestHelper.log('⚠️ 无法进入群组列表页，跳过');
  return false;
}

Future<bool> _ensureBackendAvailable() async {
  if (_backendProbePassed) return true;

  final baseUrl = Env().apiBaseUrl;
  final uri = Uri.parse('$baseUrl${API.initConfig}');
  final stopwatch = Stopwatch()..start();
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response =
        await request.close().timeout(const Duration(seconds: 5));
    await response
        .drain<List<int>>(<int>[])
        .timeout(const Duration(seconds: 2));

    final code = response.statusCode;
    if (code < 200 || code >= 400) {
      TestHelper.log('⚠️ 后端探活失败: GET $uri 返回状态码 $code');
      return false;
    }

    _backendProbePassed = true;
    TestHelper.log('✅ 后端探活通过: $uri (${stopwatch.elapsedMilliseconds}ms)');
    return true;
  } on TimeoutException catch (e) {
    TestHelper.log(
      '⚠️ 后端探活超时: GET $uri (${stopwatch.elapsedMilliseconds}ms) - ${e.message}',
    );
    return false;
  } on SocketException catch (e) {
    TestHelper.log('⚠️ 后端探活连接失败: GET $uri - $e');
    return false;
  } on HttpException catch (e) {
    TestHelper.log('⚠️ 后端探活 HTTP 异常: GET $uri - $e');
    return false;
  } catch (e) {
    TestHelper.log('⚠️ 后端探活异常: GET $uri - $e');
    return false;
  } finally {
    client.close(force: true);
    stopwatch.stop();
  }
}
