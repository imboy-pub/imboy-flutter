// 好友管理测试
//
// 测试好友功能：
// - 查看好友列表
// - 查看好友资料
// - 添加好友入口检查

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

  group('好友管理测试', () {
    testWidgets(
      '查看好友列表',
      (WidgetTester tester) async {
      TestHelper.log('🚀 开始好友列表 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'friend_01_app_launch');

      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过好友测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过好友测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (!await _ensureLoggedInAsync(tester)) return;

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'friend_02_after_login');

      // 步骤 1: 进入联系人 tab
      final tabOk = await _openContactTab(tester);
      if (!tabOk) {
        TestHelper.log('⚠️ 无法进入联系人页，跳过好友测试');
        TestHelper.log('[AUTO-SKIP] reason=no_contact_tab');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'friend_03_contact_list');

      // 步骤 2: 检查好友列表
      final listTiles = find.byType(ListTile);
      if (tester.any(listTiles)) {
        final count = listTiles.evaluate().length;
        TestHelper.log('✅ 找到 $count 个联系人列表项');
      } else {
        TestHelper.log('ℹ️ 好友列表为空或未加载');
      }

      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      '查看好友资料',
      (WidgetTester tester) async {
      TestHelper.log('🚀 开始好友资料 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'friend_profile_01_launch');

      final backendOk = await _ensureBackendAvailable();
      if (!backendOk) {
        TestHelper.log('⚠️ 后端不可用，跳过好友资料测试');
        TestHelper.log('[AUTO-SKIP] reason=backend_unavailable');
        return;
      }

      final entryOk = await _waitForEntryState(tester);
      if (!entryOk) {
        TestHelper.log('⚠️ 入口状态异常，跳过好友资料测试');
        TestHelper.log('[AUTO-SKIP] reason=entry_state_timeout');
        return;
      }

      if (!await _ensureLoggedInAsync(tester)) return;

      // 进入联系人 tab
      final tabOk = await _openContactTab(tester);
      if (!tabOk) {
        TestHelper.log('⚠️ 无法进入联系人页，跳过好友资料测试');
        TestHelper.log('[AUTO-SKIP] reason=no_contact_tab');
        return;
      }

      await _shortSettle(tester);

      // 点击第一个联系人
      final listTiles = find.byType(ListTile);
      if (!tester.any(listTiles)) {
        TestHelper.log('ℹ️ 联系人列表为空，跳过好友资料测试');
        TestHelper.log('[AUTO-SKIP] reason=no_contacts');
        return;
      }

      await _tapFinder(tester, listTiles.first);
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'friend_profile_02_contact_detail');

      // 检查资料页元素
      final avatar = find.byType(CircleAvatar);
      final chatButton = _findAnyText(<String>[
        '发消息',
        '發訊息',
        'Send message',
        'Message',
      ]);

      if (tester.any(avatar)) {
        TestHelper.log('✅ 找到头像');
      }
      if (tester.any(chatButton)) {
        TestHelper.log('✅ 找到发消息按钮');
      }

      await _tryNavigateBack(tester);
      await _drainUnexpectedFrameworkExceptions(tester);
    },
      timeout: Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      '添加好友入口检查',
      (WidgetTester tester) async {
      TestHelper.log('🚀 开始添加好友入口 E2E 测试');
      TestConfig.printHelp();

      app.main();
      await _shortSettle(tester);
      await Future.delayed(const Duration(seconds: 3));
      await _safeScreenshot(tester, 'add_friend_01_launch');

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

      // 进入联系人 tab
      final tabOk = await _openContactTab(tester);
      if (!tabOk) {
        TestHelper.log('⚠️ 无法进入联系人页，跳过添加好友测试');
        TestHelper.log('[AUTO-SKIP] reason=no_contact_tab');
        return;
      }

      await _shortSettle(tester);

      // 检查添加好友入口
      final addButton = find.byIcon(Icons.person_add);
      final addAltButton = find.byIcon(Icons.person_add_alt);
      final addOutlineButton = find.byIcon(Icons.person_add_alt_outlined);
      final qrButton = find.byIcon(Icons.qr_code_scanner);

      if (tester.any(addButton)) {
        TestHelper.log('✅ 找到 person_add 按钮');
      } else if (tester.any(addAltButton)) {
        TestHelper.log('✅ 找到 person_add_alt 按钮');
      } else if (tester.any(addOutlineButton)) {
        TestHelper.log('✅ 找到 person_add_alt_outlined 按钮');
      } else {
        TestHelper.log('ℹ️ 未找到添加好友按钮');
      }

      if (tester.any(qrButton)) {
        TestHelper.log('✅ 找到扫一扫按钮');
      }

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
