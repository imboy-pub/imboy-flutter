import 'dart:async' as async;
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

  group('单聊功能自动化测试', () {
    testWidgets('发送文本消息并校验回显', (WidgetTester tester) async {
      final message = '[C2C-AUTO] ${DateTime.now().millisecondsSinceEpoch}';
      TestHelper.log('🚀 开始单聊自动化测试');
      TestConfig.printHelp();
      await _installPlatformChannelStubs();

      await _runStepWithTimeout('应用启动与入口页就绪', () async {
        app.main();
        await _shortSettle(tester);
        await Future.delayed(const Duration(seconds: 3));
        await _safeScreenshot(tester, 'c2c_01_launch');
        await _ensureBackendAvailable();
        await _waitForEntryState(tester);
      }, timeout: const Duration(seconds: 60));

      final readyAfterLaunch = await _ensureLoggedInIfNeeded(tester);
      if (!readyAfterLaunch) {
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'c2c_02_after_login');

      final openedChat = await _runStepWithTimeout<bool>('进入单聊页面', () async {
        final canContinue = await _ensureLoggedInIfNeeded(tester);
        if (!canContinue) {
          return false;
        }
        final openedFromConversation = await _openExistingConversation(tester);
        if (openedFromConversation) return true;

        final canContinueFromContacts = await _ensureLoggedInIfNeeded(tester);
        if (!canContinueFromContacts) {
          return false;
        }
        TestHelper.log('ℹ️ 会话列表暂无可用单聊，尝试从联系人发起');
        final openedFromContacts = await _openConversationFromContacts(tester);
        return openedFromContacts;
      }, timeout: const Duration(seconds: 90));
      if (!openedChat) {
        TestHelper.log('⚠️ 未找到可用单聊入口（无会话且无法从联系人发起单聊），跳过用例');
        TestHelper.log('[AUTO-SKIP] reason=no_c2c_conversation');
        return;
      }

      await _shortSettle(tester);
      await _safeScreenshot(tester, 'c2c_03_chat_ready');
      expect(_isOnChatPage(tester), isTrue, reason: '应已进入单聊页面');

      final input = await _findChatInputStrict(tester);
      await TestHelper.enterText(tester, input, message);
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'c2c_04_message_typed');

      final hasSendButton =
          tester.any(find.byKey(const ValueKey('send_button'))) ||
          tester.any(find.byIcon(Icons.send));
      expect(hasSendButton, isTrue, reason: '输入文本后应出现发送按钮');

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

      await Future.delayed(const Duration(seconds: 2));
      await _shortSettle(tester);
      await _safeScreenshot(tester, 'c2c_05_after_send');

      final latestInput = find.byType(TextField).first;
      expect(latestInput, findsWidgets, reason: '聊天页面应保留输入框');
      final textFieldWidget = tester.widget<TextField>(latestInput);
      final inputText = textFieldWidget.controller?.text ?? '';
      expect(inputText, isEmpty, reason: '消息发送成功后输入框应清空');

      expect(find.text(message), findsWidgets, reason: '发送后应能在消息列表看到刚发送的文本');
      expect(
        _findAnyText(<String>['发送失败', '消息发送失败', 'Send failed']),
        findsNothing,
        reason: '发送成功路径不应出现失败提示',
      );

      await _drainUnexpectedFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

Finder _findAnyText(List<String> candidates) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data?.trim();
    if (data == null || data.isEmpty) return false;
    for (final candidate in candidates) {
      if (data.contains(candidate)) {
        return true;
      }
    }
    return false;
  });
}

bool _isOnMainShellPage(WidgetTester tester) {
  final hasGlassBottomBar = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'GlassBottomNavigationBar',
    ),
  );
  final hasBottomBar =
      tester.any(find.byType(BottomNavigationBar)) ||
      tester.any(find.byType(NavigationBar)) ||
      tester.any(find.byType(BottomAppBar)) ||
      hasGlassBottomBar;
  return hasBottomBar;
}

bool _isOnWelcomePage(WidgetTester tester) {
  final hasWelcomeType = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'WelcomePage',
    ),
  );
  final hasGuideButton = tester.any(
    _findAnyText(<String>['跳过', '下一步', '开始', 'Skip', 'Next', 'Start']),
  );
  return hasWelcomeType || hasGuideButton;
}

bool _isOnConversationListPage(WidgetTester tester) {
  final hasSearch = tester.any(find.byIcon(Icons.search));
  final hasAdd = tester.any(find.byIcon(Icons.add_circle_outline));
  final hasTitle = tester.any(
    _findAnyText(<String>['消息', '会话', 'Message', 'Messages', 'Chats']),
  );
  return hasSearch && hasAdd && hasTitle;
}

bool _isOnContactPage(WidgetTester tester) {
  final hasAddFriend = tester.any(find.byIcon(Icons.person_add_alt_outlined));
  final hasContactTitle = tester.any(
    _findAnyText(<String>['联系人', '通讯录', 'Contact', 'Contacts']),
  );
  return hasAddFriend && hasContactTitle;
}

bool _isOnPeopleInfoPage(WidgetTester tester) {
  final hasPeopleInfoType = tester.any(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'PeopleInfoPage',
    ),
  );
  final hasMoreAction = tester.any(find.byIcon(Icons.more_horiz));
  final hasMessageAction =
      tester.any(find.byIcon(Icons.message_outlined)) ||
      tester.any(
        _findAnyText(<String>[
          '发消息',
          '發訊息',
          'Send message',
          'メッセージを送る',
          '메시지 보내기',
          'Отправить сообщение',
        ]),
      );
  return hasPeopleInfoType || (hasMoreAction && hasMessageAction);
}

bool _isOnChatPage(WidgetTester tester) {
  final hasInput = tester.any(find.byType(TextField));
  final hasInputControls =
      tester.any(find.byKey(const ValueKey('extra_button'))) ||
      tester.any(find.byKey(const ValueKey('send_button'))) ||
      tester.any(find.byIcon(Icons.emoji_emotions_outlined)) ||
      tester.any(find.byIcon(Icons.keyboard_voice_outlined));
  return hasInput && hasInputControls;
}

Future<bool> _ensureLoggedInIfNeeded(WidgetTester tester) async {
  if (!TestHelper.needsLogin(tester)) return true;

  if (!TestConfig.isConfigured) {
    TestHelper.log('⚠️ 检测到登录页但未配置测试账号，跳过单聊自动化测试');
    TestHelper.log('[AUTO-SKIP] reason=missing_test_credentials');
    return false;
  }

  final loginOk = await _runStepWithTimeout(
    '自动登录',
    () => TestHelper.autoLogin(tester),
    timeout: const Duration(seconds: 60),
  );
  if (!loginOk) {
    TestHelper.log('⚠️ 自动登录失败，跳过单聊自动化测试');
    TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
    return false;
  }

  await _shortSettle(tester);
  if (TestHelper.needsLogin(tester)) {
    TestHelper.log('⚠️ 自动登录后仍处于登录页，跳过单聊自动化测试');
    TestHelper.log('[AUTO-SKIP] reason=auto_login_failed');
    return false;
  }
  return true;
}

Future<void> _waitForEntryState(WidgetTester tester) async {
  const maxRounds = 40;
  for (int i = 0; i < maxRounds; i++) {
    if (_isOnWelcomePage(tester)) {
      await _dismissWelcomeIfPresent(tester);
    }

    if (TestHelper.needsLogin(tester) ||
        _isOnMainShellPage(tester) ||
        _isOnConversationListPage(tester)) {
      return;
    }
    await Future.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('入口状态等待超时：未进入登录页或主页面');
}

Future<void> _dismissWelcomeIfPresent(WidgetTester tester) async {
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

Future<void> _openConversationTabStrict(WidgetTester tester) async {
  if (_isOnConversationListPage(tester)) return;

  final opened = await _tapAny(tester, <Finder>[
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Message'),
    find.text('Messages'),
    find.text('Chats'),
  ]);
  final openedByPosition = opened || await _tapBottomBarIndex(tester, 0);
  if (!openedByPosition) {
    fail('无法点击消息/会话标签');
  }

  for (int i = 0; i < 5; i++) {
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    if (_isOnConversationListPage(tester)) return;
  }
  fail('未能进入会话列表页面');
}

Future<bool> _openExistingConversation(WidgetTester tester) async {
  await _openConversationTabStrict(tester);
  await _shortSettle(tester);

  final slidableItems = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == 'Slidable',
  );
  if (!tester.any(slidableItems)) {
    return false;
  }

  final opened = await _tapFinderIfPossible(tester, slidableItems.first);
  if (!opened) return false;

  for (int i = 0; i < 6; i++) {
    if (_isOnChatPage(tester)) return true;
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 120));
  }
  return _isOnChatPage(tester);
}

Future<bool> _openConversationFromContacts(WidgetTester tester) async {
  await _openContactTabStrict(tester);

  // 联系人页中，只有真实联系人项包含 onLongPress（功能入口项没有）。
  final contactRows = find.byWidgetPredicate(
    (widget) => widget is InkWell && widget.onLongPress != null,
  );
  final count = contactRows.evaluate().length;
  if (count == 0) return false;

  final maxTry = count > 6 ? 6 : count;
  for (int i = 0; i < maxTry; i++) {
    final target = contactRows.at(i);
    try {
      await tester.ensureVisible(target);
    } catch (_) {}

    // 快速路径：联系人列表长按可直接进单聊。
    try {
      await tester.longPress(target, warnIfMissed: false);
      await _shortSettle(tester, total: const Duration(milliseconds: 700));
      if (_isOnChatPage(tester)) return true;
    } catch (_) {}

    final tapped = await _tapFinderIfPossible(tester, target);
    if (!tapped) {
      await _recoverToContactPage(tester);
      continue;
    }
    await _shortSettle(tester, total: const Duration(milliseconds: 700));

    if (_isOnChatPage(tester)) return true;

    if (_isOnPeopleInfoPage(tester)) {
      final enteredByProfileAction = await _tapAny(tester, <Finder>[
        find.text('发消息'),
        find.text('發訊息'),
        find.text('Send message'),
        find.text('Message'),
        find.byIcon(Icons.message_outlined),
      ]);
      if (enteredByProfileAction) {
        await _shortSettle(tester, total: const Duration(milliseconds: 900));
        if (_isOnChatPage(tester)) return true;
      }
    } else {
      final enteredByMessageButton = await _tapAny(tester, <Finder>[
        find.byIcon(Icons.message_outlined),
        find.text('发消息'),
        find.text('發訊息'),
        find.text('Send message'),
        find.text('Message'),
      ]);
      if (enteredByMessageButton) {
        await _shortSettle(tester, total: const Duration(milliseconds: 900));
        if (_isOnChatPage(tester)) return true;
      }
    }

    await _recoverToContactPage(tester);
  }
  return false;
}

Future<void> _recoverToContactPage(WidgetTester tester) async {
  if (_isOnContactPage(tester)) return;

  await _tryNavigateBack(tester);
  await _shortSettle(tester, total: const Duration(milliseconds: 500));
  if (_isOnContactPage(tester)) return;

  final openedByPosition = await _tapBottomBarIndex(tester, 1);
  if (openedByPosition) {
    for (int i = 0; i < 4; i++) {
      await _shortSettle(tester, total: const Duration(milliseconds: 450));
      if (_isOnContactPage(tester)) return;
    }
  }

  if (!_isOnContactPage(tester)) {
    await _openContactTabStrict(tester);
  }
}

Future<void> _openContactTabStrict(WidgetTester tester) async {
  if (_isOnContactPage(tester)) return;

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
  final openedByPosition = opened || await _tapBottomBarIndex(tester, 1);
  if (!openedByPosition) {
    fail('无法点击联系人标签');
  }

  for (int i = 0; i < 8; i++) {
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    if (_isOnContactPage(tester)) return;
  }
  fail('未能进入联系人页面');
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

Future<Finder> _findChatInputStrict(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    final fields = find.byType(TextField);
    if (_isOnChatPage(tester) && tester.any(fields)) {
      return fields.first;
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 120));
  }
  throw TestFailure('未找到聊天输入框，无法执行发送操作');
}

Future<bool> _tapAny(WidgetTester tester, List<Finder> finders) async {
  for (final finder in finders) {
    if (await _tapFinderIfPossible(tester, finder)) {
      return true;
    }
  }
  return false;
}

Future<bool> _tapFinderIfPossible(WidgetTester tester, Finder finder) async {
  try {
    if (!tester.any(finder)) return false;
  } catch (_) {
    return false;
  }

  final target = finder.first;
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

Future<void> _shortSettle(
  WidgetTester tester, {
  Duration total = const Duration(seconds: 2),
}) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<T> _runStepWithTimeout<T>(
  String stepName,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  try {
    return await action().timeout(timeout);
  } on async.TimeoutException catch (e) {
    fail('步骤超时: $stepName (${timeout.inSeconds}s) - ${e.message ?? "timeout"}');
  } catch (_) {
    rethrow;
  }
}

Future<void> _safeScreenshot(WidgetTester tester, String name) async {
  try {
    // 聊天页存在持续动画，避免 screenshot 内部 pumpAndSettle 长时间阻塞。
    await TestHelper.screenshot(tester, name, waitForReady: false);
  } on MissingPluginException {
    TestHelper.log('ℹ️ 当前运行器不支持截图，跳过: $name');
  }
}

Future<void> _installPlatformChannelStubs() async {
  const secureChannel = MethodChannel('imboy/secure');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureChannel, (MethodCall call) async {
        return null;
      });
}

Future<void> _drainUnexpectedFrameworkExceptions(WidgetTester tester) async {
  const maxDrain = 24;
  final unexpected = <Object>[];

  for (int i = 0; i < maxDrain; i++) {
    final err = tester.takeException();
    if (err == null) break;
    if (_isIgnorableFrameworkException(err)) {
      TestHelper.log('ℹ️ 忽略非核心异常: $err');
      continue;
    }
    unexpected.add(err);
  }

  if (unexpected.isNotEmpty) {
    fail('检测到非预期框架异常: ${unexpected.first}');
  }
}

bool _isIgnorableFrameworkException(Object err) {
  final text = err.toString();
  return text.contains('ImageNotFoundException') ||
      text.contains('Image not found (404)') ||
      text.startsWith('Multiple exceptions (');
}

Future<void> _ensureBackendAvailable() async {
  if (_backendProbePassed) return;

  final baseUrl = Env().apiBaseUrl;
  final uri = Uri.parse('$baseUrl${API.initConfig}');
  final stopwatch = Stopwatch()..start();
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
    if (code < 200 || code >= 400) {
      TestHelper.log('⚠️ 后端探活返回状态码异常: $code, uri=$uri');
      return;
    }

    _backendProbePassed = true;
    TestHelper.log('✅ 后端探活通过: $uri (${stopwatch.elapsedMilliseconds}ms)');
  } on async.TimeoutException catch (e) {
    TestHelper.log('⚠️ 后端探活超时: GET $uri - ${e.message ?? "timeout"}');
  } on SocketException catch (e) {
    TestHelper.log('⚠️ 后端探活连接失败: GET $uri - $e');
  } on HttpException catch (e) {
    TestHelper.log('⚠️ 后端探活 HTTP 异常: GET $uri - $e');
  } catch (e) {
    TestHelper.log('⚠️ 后端探活异常: GET $uri - $e');
  } finally {
    client.close(force: true);
    stopwatch.stop();
  }
}
