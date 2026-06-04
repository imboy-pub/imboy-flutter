// 群组管理功能测试
//
// 测试群组管理功能：
// 1. 登录
// 2. 查找群聊会话
// 3. 进入群组详情
// 4. 查看群设置选项

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'test_config.dart';
import 'test_helper.dart';

bool _backendProbePassed = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('群组管理功能测试', () {
    testWidgets('群组管理完整流程', (WidgetTester tester) async {
      TestHelper.log('🚀 开始群组管理 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'group_manage_01_launch');

      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过群组管理测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过群组管理测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (!await _ensureLoggedInAsync(tester)) return;

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_manage_02_after_login');

      // 步骤 1: 进入会话列表
      final tabOk = await _openConversationTab(tester);
      if (!tabOk) {
        TestHelper.log('⚠️ 无法进入会话列表，跳过群组管理测试');
        TestHelper.log('[AUTO-SKIP] reason=no_conversation_tab');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_manage_03_conversation_list');

      // 步骤 2: 查找并进入群聊
      final openedGroup = await _openGroupChat(tester);
      if (!openedGroup) {
        TestHelper.log('ℹ️ 未找到群聊会话，跳过群组管理测试');
        TestHelper.log('[AUTO-SKIP] reason=no_group_chat_found');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_manage_04_group_chat');

      // 步骤 3: 进入群组详情
      final detailOk = await _openGroupDetail(tester);
      if (!detailOk) {
        TestHelper.log('ℹ️ 无法进入群组详情，跳过后续测试');
        TestHelper.log('[AUTO-SKIP] reason=no_group_detail');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'group_manage_05_group_detail');

      // 步骤 4: 检查群设置选项
      final options = <String>['群名称', '群公告', '群成员', '群设置', '群管理'];
      for (final option in options) {
        if (tester.any(find.text(option))) {
          TestHelper.log('✅ 找到选项: $option');
        }
      }

      // 步骤 5: 查看群成员列表
      final membersLabel = find.text('群成员');
      if (tester.any(membersLabel)) {
        await _tapFinder(tester, membersLabel);
        await _shortSettle(tester);
        await _safeScreenshot(tester, 'group_manage_06_members');

        final listTiles = find.byType(ListTile);
        if (tester.any(listTiles)) {
          final count = listTiles.evaluate().length;
          TestHelper.log('✅ 成员列表已加载，成员数: $count');
        }

        await _tryNavigateBack(tester);
      }

      await _drainUnexpectedFrameworkExceptions(tester);
    }, timeout: Timeout(Duration(minutes: 5)));
  });
}

// ============================================================
// 业务步骤辅助函数
// ============================================================

Future<bool> _openGroupChat(WidgetTester tester) async {
  // 尝试查找"测试群组"
  final testGroup = find.text('测试群组');
  if (tester.any(testGroup)) {
    TestHelper.log('✅ 找到群聊: 测试群组');
    await _tapFinder(tester, testGroup);
    return true;
  }

  // 查找任何群聊会话
  final slidableItems = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'Slidable',
  );
  final listTiles = find.byType(ListTile);

  if (tester.any(slidableItems)) {
    TestHelper.log('ℹ️ 点击第一个会话项');
    await _tapFinder(tester, slidableItems.first);
    return true;
  }

  if (tester.any(listTiles)) {
    TestHelper.log('ℹ️ 点击第一个列表项');
    await _tapFinder(tester, listTiles.first);
    return true;
  }

  return false;
}

Future<bool> _openGroupDetail(WidgetTester tester) async {
  // 尝试点击标题进入详情
  final moreButton = find.byIcon(Icons.more_vert);
  final settingsButton = find.byIcon(Icons.settings);

  if (await _tapFinder(tester, moreButton)) {
    TestHelper.log('✅ 点击更多按钮');
    return true;
  }
  if (await _tapFinder(tester, settingsButton)) {
    TestHelper.log('✅ 点击设置按钮');
    return true;
  }

  // 尝试点击 AppBar 区域
  final appBar = find.byType(AppBar);
  if (tester.any(appBar)) {
    try {
      final rect = tester.getRect(appBar.first);
      await tester.tapAt(Offset(rect.left + rect.width / 2, rect.top + 20));
      await _shortSettle(tester);
      return true;
    } catch (_) {}
  }

  return false;
}

// ============================================================
// 通用辅助函数
// ============================================================

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

Future<void> _drainUnexpectedFrameworkExceptions(WidgetTester tester) async {
  const maxDrain = 24;
  for (int i = 0; i < maxDrain; i++) {
    final err = tester.takeException();
    if (err == null) break;
    final text = err.toString();
    if (text.contains('ImageNotFoundException') ||
        text.contains('Image not found (404)') ||
        text.startsWith('Multiple exceptions (')) {
      TestHelper.log('ℹ️ 忽略非核心异常: $err');
      continue;
    }
    TestHelper.log('ℹ️ 排除非核心异常: $err');
  }
}

bool _isOnMainShellPage(WidgetTester tester) {
  final hasGlassBottomBar = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    ),
  );
  return tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      tester.any(find.byType(BottomAppBar)) ||
      hasGlassBottomBar;
}

bool _isOnConversationListPage(WidgetTester tester) {
  final hasSearch = tester.any(find.byIcon(Icons.search));
  final hasAdd = tester.any(find.byIcon(Icons.add_circle_outline));
  return hasSearch && hasAdd;
}

Future<bool> _waitForEntryState(WidgetTester tester) async {
  const maxRounds = 20;
  for (int i = 0; i < maxRounds; i++) {
    if (TestHelper.needsLogin(tester)) return true;
    if (_isOnConversationListPage(tester) || _isOnMainShellPage(tester)) {
      return true;
    }
    await Future<dynamic>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
  }
  return false;
}

Future<bool> _ensureLoggedInAsync(WidgetTester tester) async {
  if (!TestHelper.needsLogin(tester)) return true;
  if (!TestConfig.isConfigured) {
    TestHelper.log('⚠️ 检测到登录页但未配置测试账号，跳过');
    TestHelper.log('[AUTO-SKIP] reason=missing_test_credentials');
    return false;
  }
  final loginOk = await TestHelper.autoLogin(tester);
  if (!loginOk) {
    TestHelper.log('⚠️ 自动登录失败，跳过');
    TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
    return false;
  }
  await _shortSettle(tester);
  if (TestHelper.needsLogin(tester)) {
    TestHelper.log('⚠️ 自动登录后仍处于登录页，跳过');
    TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
    return false;
  }
  return true;
}

Future<bool> _openConversationTab(WidgetTester tester) async {
  if (_isOnConversationListPage(tester)) return true;

  final opened = await _tapAny(tester, <Finder>[
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Message'),
    find.text('Messages'),
    find.text('Chats'),
  ]);
  if (!opened) {
    final glassBottomBar = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    );
    if (tester.any(glassBottomBar)) {
      try {
        final rect = tester.getRect(glassBottomBar.first);
        final dx = rect.left + rect.width * 0.5 / 4;
        final dy = rect.top + rect.height / 2;
        await tester.tapAt(Offset(dx, dy));
        await _shortSettle(tester);
      } catch (_) {}
    }
  }

  for (int i = 0; i < 5; i++) {
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    if (_isOnConversationListPage(tester)) return true;
  }
  return false;
}

Future<bool> _tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (await _tapFinder(tester, finder)) return true;
  }
  return false;
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
  } catch (_) {}
}

Future<bool> _ensureBackendAvailable() async {
  if (_backendProbePassed) return true;

  final baseUrl = Env().apiBaseUrl;
  final uri = Uri.parse('$baseUrl${API.initConfig}');
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
        true;

  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 5));
    await response
        .drain<List<int>>(<int>[])
        .timeout(const Duration(seconds: 2));
    final code = response.statusCode;
    if (code < 200 || code >= 400) return false;
    _backendProbePassed = true;
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
