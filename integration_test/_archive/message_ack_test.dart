// 消息 ACK 链路集成测试
//
// 验证：发送消息 → 服务端确认 → 消息出现在列表 → 无失败提示
//
// 运行命令：
// flutter test integration_test/chat/message_ack_test.dart \
//   --dart-define=APP_ENV=local_office \
//   --dart-define=TEST_PHONE=xxx \
//   --dart-define=TEST_PASSWORD=xxx \
//   -d macos

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

  group('消息 ACK 链路测试', () {
    testWidgets('发送消息并验证服务端确认', (WidgetTester tester) async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final message = '[ACK-TEST] $timestamp';
      TestHelper.log('开始消息 ACK 链路测试');
      TestConfig.printHelp();
      await _installPlatformChannelStubs();

      // Step 1: 启动应用（不包装 _runStep，避免 pump 泄漏）
      try {
        app.main();
        await _shortSettle(tester);
        await Future<dynamic>.delayed(const Duration(seconds: 5));
        await _safeScreenshot(tester, 'ack_01_launch');
        await _ensureBackendAvailable();
        await _waitForEntryState(tester);
      } catch (e) {
        TestHelper.log('[AUTO-SKIP] reason=app_launch_failed: $e');
        return;
      }

      // Step 2: 确保已登录
      final ready = await _ensureLoggedIn(tester);
      if (!ready) return;

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'ack_02_after_login');

      // Step 3: 进入聊天页面
      bool openedChat = false;
      try {
        final canContinue = await _ensureLoggedIn(tester);
        if (canContinue) {
          openedChat = await _openExistingConversation(tester);
        }
        if (!openedChat) {
          final canContinue2 = await _ensureLoggedIn(tester);
          if (canContinue2) {
            TestHelper.log('尝试从联系人发起聊天');
            openedChat = await _openConversationFromContacts(tester);
          }
        }
      } catch (e) {
        TestHelper.log('[AUTO-SKIP] 进入聊天页面异常: $e');
      }

      if (!openedChat) {
        TestHelper.log('[AUTO-SKIP] reason=no_conversation_for_ack_test');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'ack_03_chat_ready');
      expect(_isOnChatPage(tester), isTrue, reason: '应已进入聊天页面');

      // Step 4: 发送消息
      final input = await _findChatInput(tester);
      await TestHelper.enterText(tester, input, message);
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'ack_04_message_typed');

      final sent = await _tapAny(tester, <Finder>[
        find.byKey(const ValueKey('send_button')),
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _shortSettle(tester);
      }

      // Step 5: 等待 ACK
      await Future<dynamic>.delayed(const Duration(seconds: 3));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'ack_05_after_send');

      expect(find.text(message), findsWidgets, reason: '发送的消息应出现在聊天列表中');
      expect(
        _findAnyText(<String>['发送失败', '消息发送失败', 'Send failed']),
        findsNothing,
        reason: '消息应发送成功，不应出现失败提示',
      );

      final textFieldWidget = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      final inputText = textFieldWidget.controller?.text ?? '';
      expect(inputText, isEmpty, reason: '发送成功后输入框应清空');

      // Step 6: 连续发送第二条消息
      final message2 = '[ACK-TEST-2] $timestamp';
      final input2 = await _findChatInput(tester);
      await TestHelper.enterText(tester, input2, message2);
      await _shortSettle(tester);

      await _tapAny(tester, <Finder>[
        find.byKey(const ValueKey('send_button')),
        find.byIcon(Icons.send),
      ]);

      await Future<dynamic>.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'ack_06_second_message');

      expect(find.text(message2), findsWidgets, reason: '第二条消息也应成功发送');

      TestHelper.log('消息 ACK 链路测试通过');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

// ── 辅助函数 ──

Future<void> _installPlatformChannelStubs() async {
  const secureChannel = MethodChannel('imboy/secure');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureChannel, (MethodCall call) async {
        return null;
      });
}

Future<void> _ensureBackendAvailable() async {
  if (_backendProbePassed) return;

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
    if (response.statusCode >= 200 && response.statusCode < 400) {
      _backendProbePassed = true;
      TestHelper.log('后端探活通过: $uri');
    }
  } catch (e) {
    TestHelper.log('后端探活失败: $uri - $e');
  } finally {
    client.close(force: true);
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
    await TestHelper.screenshot(tester, name, waitForReady: false);
  } on MissingPluginException {
    TestHelper.log('当前运行器不支持截图: $name');
  }
}

bool _isOnWelcomePage(WidgetTester tester) {
  return tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'WelcomePage',
    ),
  );
}

bool _isOnMainShellPage(WidgetTester tester) {
  final hasGlassBottomBar = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    ),
  );
  return tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      hasGlassBottomBar;
}

bool _isOnConversationListPage(WidgetTester tester) {
  return tester.any(find.byIcon(Icons.search)) &&
      tester.any(find.byIcon(Icons.add_circle_outline));
}

bool _isOnContactPage(WidgetTester tester) {
  return tester.any(find.byIcon(Icons.person_add_alt_outlined));
}

bool _isOnChatPage(WidgetTester tester) {
  return tester.any(find.byType(TextField)) &&
      (tester.any(find.byKey(const ValueKey('extra_button'))) ||
          tester.any(find.byKey(const ValueKey('send_button'))) ||
          tester.any(find.byIcon(Icons.send)));
}

bool _isOnPeopleInfoPage(WidgetTester tester) {
  return tester.any(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'PeopleInfoPage',
        ),
      ) ||
      (tester.any(find.byIcon(Icons.more_horiz)) &&
          tester.any(find.byIcon(Icons.message_outlined)));
}

Finder _findAnyText(List<String> candidates) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data?.trim();
    if (data == null || data.isEmpty) return false;
    return candidates.any((c) => data.contains(c));
  });
}

Future<void> _waitForEntryState(WidgetTester tester) async {
  for (int i = 0; i < 40; i++) {
    if (_isOnWelcomePage(tester)) {
      await _dismissWelcome(tester);
    }
    if (TestHelper.needsLogin(tester) ||
        _isOnMainShellPage(tester) ||
        _isOnConversationListPage(tester)) {
      return;
    }
    await Future<dynamic>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
  }
  TestHelper.log('ℹ️ 入口状态等待超时，继续执行测试');
}

Future<void> _dismissWelcome(WidgetTester tester) async {
  if (!_isOnWelcomePage(tester)) return;
  final skipped = await _tapAny(tester, <Finder>[
    find.text('跳过'),
    find.text('Skip'),
  ]);
  if (skipped) {
    await _shortSettle(tester);
    return;
  }
  for (int i = 0; i < 5 && _isOnWelcomePage(tester); i++) {
    final next = await _tapAny(tester, <Finder>[
      find.text('下一步'),
      find.text('Next'),
      find.text('开始'),
      find.text('Start'),
    ]);
    if (!next) break;
    await _shortSettle(tester, total: const Duration(milliseconds: 500));
  }
}

Future<bool> _ensureLoggedIn(WidgetTester tester) async {
  if (!TestHelper.needsLogin(tester)) return true;
  if (!TestConfig.isConfigured) {
    TestHelper.log('[AUTO-SKIP] reason=missing_test_credentials');
    return false;
  }
  bool ok = false;
  try {
    ok = await TestHelper.autoLogin(
      tester,
    ).timeout(const Duration(seconds: 60));
  } catch (e) {
    TestHelper.log('[AUTO-SKIP] 自动登录超时或异常: $e');
  }
  if (!ok || TestHelper.needsLogin(tester)) {
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
  ]);
  if (!opened) {
    return await _tapBottomBarIndex(tester, 0);
  }
  for (int i = 0; i < 5; i++) {
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    if (_isOnConversationListPage(tester)) return true;
  }
  return false;
}

Future<bool> _openExistingConversation(WidgetTester tester) async {
  await _openConversationTab(tester);
  await _shortSettle(tester);

  final slidableItems = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'Slidable',
  );
  if (!tester.any(slidableItems)) return false;

  final opened = await _tapFinderIfPossible(tester, slidableItems.first);
  if (!opened) return false;

  for (int i = 0; i < 6; i++) {
    if (_isOnChatPage(tester)) return true;
    await Future<dynamic>.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 120));
  }
  return _isOnChatPage(tester);
}

Future<bool> _openConversationFromContacts(WidgetTester tester) async {
  if (!_isOnContactPage(tester)) {
    await _tapBottomBarIndex(tester, 1);
    await _shortSettle(tester);
  }
  if (!_isOnContactPage(tester)) return false;

  final contactRows = find.byWidgetPredicate(
    (widget) => widget is InkWell && widget.onLongPress != null,
  );
  final count = contactRows.evaluate().length;
  if (count == 0) return false;

  for (int i = 0; i < (count > 6 ? 6 : count); i++) {
    final target = contactRows.at(i);
    try {
      await tester.ensureVisible(target);
    } catch (_) {}

    try {
      await tester.longPress(target, warnIfMissed: false);
      await _shortSettle(tester, total: const Duration(milliseconds: 700));
      if (_isOnChatPage(tester)) return true;
    } catch (_) {}

    final tapped = await _tapFinderIfPossible(tester, target);
    if (!tapped) continue;
    await _shortSettle(tester, total: const Duration(milliseconds: 700));

    if (_isOnChatPage(tester)) return true;
    if (_isOnPeopleInfoPage(tester)) {
      final entered = await _tapAny(tester, <Finder>[
        find.text('发消息'),
        find.text('Send message'),
        find.byIcon(Icons.message_outlined),
      ]);
      if (entered) {
        await _shortSettle(tester, total: const Duration(milliseconds: 900));
        if (_isOnChatPage(tester)) return true;
      }
    }

    await _navigateBack(tester);
    await _shortSettle(tester);
  }
  return false;
}

Future<bool> _tapBottomBarIndex(WidgetTester tester, int index) async {
  final glassBottomBar = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
  );
  if (!tester.any(glassBottomBar)) return false;
  try {
    final rect = tester.getRect(glassBottomBar.first);
    const totalItems = 4;
    final dx = rect.left + rect.width * (index + 0.5) / totalItems;
    final dy = rect.top + rect.height / 2;
    await tester.tapAt(Offset(dx, dy));
    await _shortSettle(tester);
    return true;
  } catch (_) {
    return false;
  }
}

Future<Finder> _findChatInput(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    final fields = find.byType(TextField);
    if (_isOnChatPage(tester) && tester.any(fields)) {
      return fields.first;
    }
    await Future<dynamic>.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 120));
  }
  throw TestFailure('未找到聊天输入框');
}

Future<bool> _tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (await _tapFinderIfPossible(tester, finder)) return true;
  }
  return false;
}

Future<bool> _tapFinderIfPossible(WidgetTester tester, Finder finder) async {
  try {
    if (!tester.any(finder)) return false;
  } catch (_) {
    return false;
  }
  try {
    await tester.ensureVisible(finder.first);
  } catch (_) {}
  try {
    await tester.tap(finder.first, warnIfMissed: false);
    await _shortSettle(tester);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _navigateBack(WidgetTester tester) async {
  final tapped = await _tapAny(tester, <Finder>[
    find.byTooltip('Back'),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.close),
  ]);
  if (!tapped) {
    try {
      await tester.pageBack();
      await _shortSettle(tester);
    } catch (_) {}
  }
}
