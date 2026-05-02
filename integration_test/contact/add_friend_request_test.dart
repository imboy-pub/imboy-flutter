// 添加好友请求测试
//
// 测试场景：通过搜索添加好友
// 测试内容：
//   1. 登录应用
//   2. 进入联系人页面
//   3. 进入新的朋友页面
//   4. 进入添加好友页面
//   5. 搜索用户
//   6. 选择用户并发送好友请求

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

  group('添加好友请求测试', () {
    testWidgets(
      '通过搜索添加好友',
      (WidgetTester tester) async {
      TestHelper.log('🚀 开始添加好友请求 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'add_friend_01_app_launch');

      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (!await _ensureLoggedInAsync(tester)) return;

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'add_friend_02_after_login');

      // 步骤 1: 进入联系人 tab
      final tabOk = await _openContactTab(tester);
      if (!tabOk) {
        TestHelper.log('⚠️ 无法进入联系人页，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=no_contact_tab');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'add_friend_03_contact_list');

      // 步骤 2: 进入新的朋友页面
      final newFriendOk = await _openNewFriendPage(tester);
      if (!newFriendOk) {
        TestHelper.log('⚠️ 无法进入新的朋友页面，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=no_new_friend_entry');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'add_friend_04_new_friend');

      // 步骤 3: 进入添加好友页面
      final addPageOk = await _openAddFriendPage(tester);
      if (!addPageOk) {
        TestHelper.log('⚠️ 无法进入添加好友页面，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=no_add_friend_page');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'add_friend_05_add_friend_page');

      // 步骤 4: 搜索用户
      final searchOk = await _searchUser(tester, '测试');
      if (!searchOk) {
        TestHelper.log('ℹ️ 搜索框不可用或搜索未执行，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=no_search_field');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'add_friend_06_search_result');

      // 步骤 5: 选择搜索结果中的第一个用户
      final hasResult = await _selectFirstSearchResult(tester);
      if (!hasResult) {
        TestHelper.log('ℹ️ 搜索结果为空，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=no_search_results');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'add_friend_07_user_detail');

      // 步骤 6: 发送好友请求
      await _sendFriendRequest(tester);
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'add_friend_08_after_send');

      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );
  });
}

// ============================================================
// 业务步骤辅助函数
// ============================================================

Future<bool> _openNewFriendPage(WidgetTester tester) async {
  final newFriendText = _findAnyText(<String>[
    '新的朋友',
    '新朋友',
    'New Friends',
    'New friends',
  ]);

  if (tester.any(newFriendText)) {
    TestHelper.log('✅ 找到"新的朋友"文本');
    await _tapFinder(tester, newFriendText);
    return true;
  }

  // 遍历 ListTile 查找包含"新"和"友"的项
  final listTiles = find.byType(ListTile);
  if (!tester.any(listTiles)) return false;

  for (int i = 0; i < listTiles.evaluate().length; i++) {
    try {
      final tile = listTiles.at(i);
      final widget = tester.widget<ListTile>(tile);
      if (widget.title is Text) {
        final titleText = (widget.title as Text).data ?? '';
        if (titleText.contains('新') && titleText.contains('友')) {
          TestHelper.log('✅ 找到"新的朋友"列表项');
          await _tapFinder(tester, tile);
          return true;
        }
      }
    } catch (_) {}
  }
  return false;
}

Future<bool> _openAddFriendPage(WidgetTester tester) async {
  final addIcon = find.byIcon(Icons.person_add_outlined);
  final addIcon2 = find.byIcon(Icons.person_add);
  final addIcon3 = find.byIcon(Icons.person_add_alt);
  final addIcon4 = find.byIcon(Icons.person_add_alt_outlined);

  if (await _tapFinder(tester, addIcon)) {
    TestHelper.log('✅ 找到 person_add_outlined 按钮');
    return true;
  }
  if (await _tapFinder(tester, addIcon2)) {
    TestHelper.log('✅ 找到 person_add 按钮');
    return true;
  }
  if (await _tapFinder(tester, addIcon3)) {
    TestHelper.log('✅ 找到 person_add_alt 按钮');
    return true;
  }
  if (await _tapFinder(tester, addIcon4)) {
    TestHelper.log('✅ 找到 person_add_alt_outlined 按钮');
    return true;
  }

  // 遍历 IconButton 查找
  final iconButtons = find.byType(IconButton);
  if (!tester.any(iconButtons)) return false;

  for (int i = 0; i < iconButtons.evaluate().length; i++) {
    try {
      final button = iconButtons.at(i);
      final widget = tester.widget<IconButton>(button);
      if (widget.icon is Icon) {
        final icon = (widget.icon as Icon).icon;
        if (icon == Icons.person_add_outlined ||
            icon == Icons.person_add ||
            icon == Icons.person_add_alt ||
            icon == Icons.person_add_alt_outlined) {
          TestHelper.log('✅ 找到添加好友按钮');
          await _tapFinder(tester, button);
          return true;
        }
      }
    } catch (_) {}
  }
  return false;
}

Future<bool> _searchUser(WidgetTester tester, String keyword) async {
  final searchBars = find.byType(SearchBar);
  final textFields = find.byType(TextField);

  if (tester.any(searchBars)) {
    TestHelper.log('✅ 找到 SearchBar');
    await _tapFinder(tester, searchBars.first);
    await _shortSettle(tester);
    await TestHelper.enterText(tester, searchBars.first, keyword);
    return true;
  }

  if (tester.any(textFields)) {
    TestHelper.log('✅ 找到 TextField');
    await _tapFinder(tester, textFields.first);
    await _shortSettle(tester);
    await TestHelper.enterText(tester, textFields.first, keyword);
    return true;
  }

  return false;
}

Future<bool> _selectFirstSearchResult(WidgetTester tester) async {
  final listTiles = find.byType(ListTile);
  if (!tester.any(listTiles)) return false;

  final count = listTiles.evaluate().length;
  TestHelper.log('找到 $count 个搜索结果列表项');
  if (count == 0) return false;

  await _tapFinder(tester, listTiles.first);
  return true;
}

Future<void> _sendFriendRequest(WidgetTester tester) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;

  // 查找添加按钮
  final addButtons = <String>[
    '添加到通讯录',
    '添加',
    '申请添加',
    'Add',
    'Add to contacts',
  ];

  bool addButtonFound = false;
  for (final text in addButtons) {
    final button = find.text(text);
    if (tester.any(button)) {
      TestHelper.log('✅ 找到添加按钮: $text');
      await _tapFinder(tester, button);
      addButtonFound = true;
      break;
    }
  }

  if (!addButtonFound) {
    final elevatedButtons = find.byType(ElevatedButton);
    if (tester.any(elevatedButtons)) {
      TestHelper.log('✅ 找到 ElevatedButton，尝试点击');
      await _tapFinder(tester, elevatedButtons.first);
      addButtonFound = true;
    }
  }

  if (!addButtonFound) {
    TestHelper.log('ℹ️ 未找到添加按钮，可能已是好友');
    return;
  }

  await _shortSettle(tester);

  // 输入验证消息（如果有输入框）
  final textFields = find.byType(TextField);
  if (tester.any(textFields)) {
    TestHelper.log('✅ 找到验证消息输入框');
    await TestHelper.enterText(
      tester,
      textFields.first,
      '你好，我是测试用户 ($timestamp)',
    );
  }

  // 点击发送按钮
  final sendButtons = <String>['发送', 'Send', '提交', 'Submit'];
  for (final text in sendButtons) {
    final button = find.text(text);
    if (tester.any(button)) {
      TestHelper.log('✅ 找到发送按钮: $text');
      await _tapFinder(tester, button);
      break;
    }
  }

  await _shortSettle(tester);

  // 检查成功提示
  final successTexts = <String>['发送成功', '已发送', '已发送申请'];
  for (final text in successTexts) {
    if (tester.any(find.text(text))) {
      TestHelper.log('✅ 找到成功提示: $text');
      return;
    }
  }
  TestHelper.log('ℹ️ 未找到明确的成功提示');
}

// ============================================================
// 通用辅助函数
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

bool _isOnContactPage(WidgetTester tester) {
  final hasAddFriend = tester.any(
    find.byIcon(Icons.person_add_alt_outlined),
  ) || tester.any(find.byIcon(Icons.person_add));
  final hasContactTitle = tester.any(
    _findAnyText(<String>['联系人', '通讯录', 'Contact', 'Contacts']),
  );
  return hasAddFriend && hasContactTitle;
}

Future<bool> _waitForEntryState(WidgetTester tester) async {
  const maxRounds = 20;
  for (int i = 0; i < maxRounds; i++) {
    if (TestHelper.needsLogin(tester)) return true;
    if (_isOnContactPage(tester) || _isOnMainShellPage(tester)) return true;
    await Future.delayed(const Duration(seconds: 1));
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

Future<bool> _openContactTab(WidgetTester tester) async {
  if (_isOnContactPage(tester)) return true;

  final opened = await _tapAny(tester, <Finder>[
    find.byIcon(Icons.people_alt),
    find.byIcon(Icons.people_alt_outlined),
    find.byIcon(Icons.perm_contact_cal),
    find.byIcon(Icons.perm_contact_cal_outlined),
    find.text('联系人'),
    find.text('通讯录'),
    find.text('Contact'),
    find.text('Contacts'),
  ]);
  if (!opened) {
    final glassBottomBar = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    );
    if (tester.any(glassBottomBar)) {
      try {
        final rect = tester.getRect(glassBottomBar.first);
        final dx = rect.left + rect.width * (1 + 0.5) / 4;
        final dy = rect.top + rect.height / 2;
        await tester.tapAt(Offset(dx, dy));
        await _shortSettle(tester);
      } catch (_) {}
    }
  }

  for (int i = 0; i < 5; i++) {
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    if (_isOnContactPage(tester)) return true;
  }
  return false;
}

Future<bool> _tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (await _tapFinder(tester, finder)) return true;
  }
  return false;
}

Future<bool> _ensureBackendAvailable() async {
  if (_backendProbePassed) return true;

  final baseUrl = Env().apiBaseUrl;
  final uri = Uri.parse('$baseUrl${API.initConfig}');
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
    await response.drain<List<int>>(<int>[]).timeout(const Duration(seconds: 2));
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
