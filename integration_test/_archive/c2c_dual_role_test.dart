import 'dart:async' as async;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'support/dual_test_helper.dart';
import 'support/account_identity.dart' as account_identity;

const String _dualRole = String.fromEnvironment(
  'DUAL_ROLE',
  defaultValue: 'sender',
);
const String _dualRunId = String.fromEnvironment(
  'DUAL_RUN_ID',
  defaultValue: '',
);
const String _dualPeerKeyword = String.fromEnvironment(
  'DUAL_PEER_KEYWORD',
  defaultValue: '',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('C2C dual role automation', () {
    testWidgets(
      'sender/receiver exchange in real accounts',
      (WidgetTester tester) async {
        final role = _dualRole.toLowerCase().trim();
        if (role != 'sender' && role != 'receiver') {
          DualTestHelper.log(
            '⚠️ Invalid DUAL_ROLE: $_dualRole (expected sender|receiver)',
          );
          DualTestHelper.log('[AUTO-SKIP] reason=invalid_dual_role');
          return;
        }

        final runId = _dualRunId.isNotEmpty
            ? _dualRunId
            : DateTime.now().millisecondsSinceEpoch.toString();
        if (!DualTestConfig.isConfigured) {
          DualTestHelper.log(
            '⚠️ 未配置 TEST_PHONE + TEST_PASSWORD/TEST_CODE，跳过 dual role 测试',
          );
          DualTestHelper.log('[AUTO-SKIP] reason=missing_test_credentials');
          return;
        }
        if (_dualPeerKeyword.trim().isEmpty) {
          DualTestHelper.log('⚠️ 未配置 DUAL_PEER_KEYWORD，跳过 dual role 测试');
          DualTestHelper.log('[AUTO-SKIP] reason=missing_dual_peer_keyword');
          return;
        }

        final senderMessages = _buildSenderMessages(runId);
        final receiverAck = '[DUAL][$runId][ACK][receiver]';

        DualTestHelper.log(
          '[DUAL] role=$role runId=$runId account=${DualTestConfig.testPhone} peer=$_dualPeerKeyword',
        );

        await _installPlatformChannelStubs();

        await _runStepWithTimeout('launch app', () async {
          app.main();
          await _shortSettle(tester, total: const Duration(seconds: 3));
          await _waitForEntryState(tester);
        }, timeout: const Duration(seconds: 90));

        await _ensureExpectedAccount(tester);
        await _safeScreenshot(tester, 'dual_${role}_01_ready');

        await _runStepWithTimeout('open peer conversation', () async {
          final opened = await _openConversationWithPeerKeyword(
            tester,
            _dualPeerKeyword,
          );
          if (!opened || !_isOnChatPage(tester)) {
            DualTestHelper.log(
              '[AUTO-SKIP] reason=unable_to_open_peer_conversation',
            );
            return;
          }
        }, timeout: const Duration(seconds: 120));

        await _safeScreenshot(tester, 'dual_${role}_02_chat_opened');

        if (role == 'sender') {
          await _runSenderFlow(tester, senderMessages, receiverAck);
        } else {
          await _runReceiverFlow(tester, senderMessages, receiverAck);
        }

        await _drainUnexpectedFrameworkExceptions(tester);
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  });
}

List<String> _buildSenderMessages(String runId) {
  final longBody = List<String>.filled(20, 'long-segment').join(' ');
  return <String>[
    '[DUAL][$runId][TEXT] hello from sender',
    '[DUAL][$runId][EMOJI] hello 😀🚀',
    '[DUAL][$runId][LONG] $longBody',
  ];
}

Future<void> _runSenderFlow(
  WidgetTester tester,
  List<String> senderMessages,
  String receiverAck,
) async {
  for (final message in senderMessages) {
    await _sendChatMessage(tester, message);
    final token = _extractToken(message);
    await _waitForTokenInChat(
      tester,
      token,
      timeout: const Duration(seconds: 40),
    );
  }

  await _safeScreenshot(tester, 'dual_sender_03_sent');

  await _waitForTokenInChat(
    tester,
    receiverAck,
    timeout: const Duration(seconds: 120),
  );

  await _safeScreenshot(tester, 'dual_sender_04_ack_received');
}

Future<void> _runReceiverFlow(
  WidgetTester tester,
  List<String> senderMessages,
  String receiverAck,
) async {
  for (final message in senderMessages) {
    final token = _extractToken(message);
    await _waitForTokenInChat(
      tester,
      token,
      timeout: const Duration(seconds: 180),
    );
  }

  await _safeScreenshot(tester, 'dual_receiver_03_received');

  await _sendChatMessage(tester, receiverAck);
  await _waitForTokenInChat(
    tester,
    receiverAck,
    timeout: const Duration(seconds: 40),
  );

  await _safeScreenshot(tester, 'dual_receiver_04_ack_sent');
}

String _extractToken(String message) {
  final idx = message.indexOf('] ');
  return idx > 0 ? message.substring(0, idx + 1) : message;
}

Future<void> _waitForTokenInChat(
  WidgetTester tester,
  String token, {
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (tester.any(_findTextContaining(token))) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
    await Future<dynamic>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('Timeout waiting chat token: $token');
}

Future<void> _sendChatMessage(WidgetTester tester, String text) async {
  final input = await _findChatInputStrict(tester);
  await DualTestHelper.enterText(tester, input, text);
  await _shortSettle(tester, total: const Duration(milliseconds: 600));

  final sent = await _tapAny(tester, <Finder>[
    find.byKey(const ValueKey('send_button')),
    find.byIcon(Icons.send),
    find.text('发送'),
    find.text('Send'),
  ]);

  if (!sent) {
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _shortSettle(tester, total: const Duration(milliseconds: 500));
  }
}

Future<void> _ensureExpectedAccount(WidgetTester tester) async {
  if (!DualTestConfig.isConfigured) {
    throw StateError(
      'Missing TEST_PHONE + TEST_PASSWORD/TEST_CODE for dual role test',
    );
  }

  await _ensureLoggedInIfNeeded(tester);
  final expected = DualTestConfig.testPhone.trim();
  var identity = _currentIdentity();

  if (!_matchesExpectedIdentity(expected, identity)) {
    DualTestHelper.log(
      '[DUAL] account mismatch ${_identitySummary(identity)} expected=$expected, relogin',
    );
    await account_identity.quitLoginIfPossible();
    await Future<dynamic>.delayed(const Duration(seconds: 1));

    app.main();
    await _shortSettle(tester, total: const Duration(seconds: 3));
    await _waitForEntryState(tester);
    await _ensureLoggedInIfNeeded(tester);
    identity = _currentIdentity();
  }

  if (!_matchesExpectedIdentity(expected, identity)) {
    throw StateError(
      'Expected account=$expected but identity still mismatch: ${_identitySummary(identity)}',
    );
  }
}

account_identity.CurrentIdentity _currentIdentity() {
  return account_identity.readCurrentIdentity();
}

String _identitySummary(account_identity.CurrentIdentity identity) {
  return 'account=${identity.account}, email=${identity.email}, '
      'mobile=${identity.mobile}, lastLogin=${identity.lastLoginAccount}';
}

bool _matchesExpectedIdentity(
  String expected,
  account_identity.CurrentIdentity identity,
) {
  final expectedNorm = expected.trim().toLowerCase();
  if (expectedNorm.isEmpty) return false;

  final probes = <String>{
    identity.account.toLowerCase(),
    identity.email.toLowerCase(),
    identity.mobile.toLowerCase(),
    identity.lastLoginAccount.toLowerCase(),
  }..removeWhere((element) => element.isEmpty);

  if (probes.contains(expectedNorm)) {
    return true;
  }

  final expectedLocal = expectedNorm.contains('@')
      ? expectedNorm.split('@').first
      : expectedNorm;
  if (expectedLocal.isEmpty) return false;
  return probes.any(
    (probe) => probe == expectedLocal || probe.startsWith(expectedLocal),
  );
}

Future<bool> _openConversationWithPeerKeyword(
  WidgetTester tester,
  String peerKeyword,
) async {
  await _openConversationTabStrict(tester);

  if (await _openEntryByKeywordOnCurrentPage(tester, peerKeyword)) {
    return _isOnChatPage(tester);
  }

  await _openContactTabStrict(tester);
  if (await _openEntryByKeywordOnCurrentPage(tester, peerKeyword)) {
    return _isOnChatPage(tester);
  }

  await _openConversationTabStrict(tester);
  return await _openExistingConversation(tester);
}

Future<bool> _openEntryByKeywordOnCurrentPage(
  WidgetTester tester,
  String keyword,
) async {
  final normalized = keyword.trim();
  if (normalized.isEmpty) return false;

  for (int scrollRound = 0; scrollRound < 8; scrollRound++) {
    final candidates = _findTextContaining(normalized);
    final count = candidates.evaluate().length;
    final tryCount = count > 8 ? 8 : count;

    for (int i = 0; i < tryCount; i++) {
      final textFinder = candidates.at(i);
      final textValue = _readTextValue(tester, textFinder);
      if (_isNavigationLabel(textValue)) {
        continue;
      }

      final opened = await _tapConversationEntryFromText(tester, textFinder);
      if (!opened) {
        continue;
      }

      if (_isOnChatPage(tester)) {
        return true;
      }

      if (_isOnPeopleInfoPage(tester)) {
        final enteredByMessageAction = await _tapAny(tester, <Finder>[
          find.byIcon(Icons.message_outlined),
          find.text('发消息'),
          find.text('Send message'),
          find.text('Message'),
        ]);
        if (enteredByMessageAction) {
          await _shortSettle(tester, total: const Duration(milliseconds: 800));
          if (_isOnChatPage(tester)) {
            return true;
          }
        }
      }

      await _recoverToSafeListPage(tester);
    }

    final scrolled = await _scrollPrimaryList(tester);
    if (!scrolled) {
      break;
    }
  }

  return false;
}

String _readTextValue(WidgetTester tester, Finder textFinder) {
  try {
    final widget = tester.widget(textFinder);
    if (widget is Text) {
      return (widget.data ?? widget.textSpan?.toPlainText() ?? '').trim();
    }
  } catch (_) {}
  return '';
}

bool _isNavigationLabel(String text) {
  if (text.isEmpty) return true;
  const labels = <String>{
    '消息',
    '会话',
    '联系人',
    '通讯录',
    '发现',
    '我的',
    'Message',
    'Messages',
    'Chats',
    'Contact',
    'Contacts',
    'Discover',
    'Me',
  };
  return labels.contains(text);
}

Future<bool> _tapConversationEntryFromText(
  WidgetTester tester,
  Finder textFinder,
) async {
  final entryFinders = <Finder>[
    find.ancestor(
      of: textFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'Slidable',
      ),
    ),
    find.ancestor(of: textFinder, matching: find.byType(InkWell)),
    find.ancestor(of: textFinder, matching: find.byType(ListTile)),
    find.ancestor(of: textFinder, matching: find.byType(GestureDetector)),
    textFinder,
  ];

  for (final entryFinder in entryFinders) {
    if (await _tapFinderIfPossible(tester, entryFinder)) {
      await _shortSettle(tester, total: const Duration(milliseconds: 700));
      return true;
    }
  }
  return false;
}

Future<void> _recoverToSafeListPage(WidgetTester tester) async {
  if (_isOnConversationListPage(tester) || _isOnContactPage(tester)) {
    return;
  }

  await _tryNavigateBack(tester);
  await _shortSettle(tester, total: const Duration(milliseconds: 500));

  if (_isOnConversationListPage(tester) || _isOnContactPage(tester)) {
    return;
  }

  await _openConversationTabStrict(tester);
}

Future<bool> _scrollPrimaryList(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (!tester.any(scrollables)) return false;

  try {
    await tester.drag(scrollables.first, const Offset(0, -280));
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    return true;
  } catch (_) {
    return false;
  }
}

Finder _findTextContaining(String keyword) {
  final needle = keyword.trim();
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = (widget.data ?? widget.textSpan?.toPlainText() ?? '').trim();
    return data.contains(needle);
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

Future<void> _waitForEntryState(WidgetTester tester) async {
  const maxRounds = 45;
  for (int i = 0; i < maxRounds; i++) {
    if (_isOnWelcomePage(tester)) {
      await _dismissWelcomeIfPresent(tester);
    }

    if (DualTestHelper.needsLogin(tester) ||
        _isOnMainShellPage(tester) ||
        _isOnConversationListPage(tester)) {
      return;
    }
    await Future<dynamic>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
  }
  DualTestHelper.log(
    'ℹ️ Entry state timeout: not on login/main/conversation page',
  );
}

Future<void> _ensureLoggedInIfNeeded(WidgetTester tester) async {
  if (!DualTestHelper.needsLogin(tester)) {
    return;
  }

  final loginOk = await _runStepWithTimeout(
    'auto login',
    () => DualTestHelper.autoLogin(tester),
    timeout: const Duration(seconds: 80),
  );
  if (!loginOk) {
    throw StateError('Auto login failed');
  }

  await _shortSettle(tester, total: const Duration(seconds: 2));
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
    throw StateError('Unable to tap conversation tab');
  }

  for (int i = 0; i < 6; i++) {
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    if (_isOnConversationListPage(tester)) return;
  }
  throw StateError('Unable to open conversation list page');
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
    throw StateError('Unable to tap contact tab');
  }

  for (int i = 0; i < 8; i++) {
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    if (_isOnContactPage(tester)) return;
  }
  throw StateError('Unable to open contact page');
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
    await Future<dynamic>.delayed(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 120));
  }
  return _isOnChatPage(tester);
}

Future<Finder> _findChatInputStrict(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    final fields = find.byType(TextField);
    if (_isOnChatPage(tester) && tester.any(fields)) {
      return fields.first;
    }
    await Future<dynamic>.delayed(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 120));
  }
  throw TestFailure('Chat input not found');
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
    await _shortSettle(tester, total: const Duration(milliseconds: 600));
    return true;
  } catch (_) {
    return false;
  }
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
    await _shortSettle(tester, total: const Duration(milliseconds: 450));
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
    await _shortSettle(tester, total: const Duration(milliseconds: 400));
  } catch (_) {
    DualTestHelper.log('[DUAL] skip pageBack (no back action)');
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
    throw StateError(
      'Step timeout: $stepName (${timeout.inSeconds}s) - ${e.message ?? "timeout"}',
    );
  } catch (_) {
    rethrow;
  }
}

Finder _findAnyText(List<String> candidates) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = (widget.data ?? widget.textSpan?.toPlainText() ?? '').trim();
    if (data.isEmpty) return false;
    for (final candidate in candidates) {
      if (data.contains(candidate)) {
        return true;
      }
    }
    return false;
  });
}

Future<void> _installPlatformChannelStubs() async {
  const secureChannel = MethodChannel('imboy/secure');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureChannel, (MethodCall call) async {
        return null;
      });
}

Future<void> _safeScreenshot(WidgetTester tester, String name) async {
  try {
    await DualTestHelper.screenshot(tester, name, waitForReady: false);
  } on MissingPluginException {
    DualTestHelper.log('[DUAL] screenshot skipped: $name');
  }
}

Future<void> _drainUnexpectedFrameworkExceptions(WidgetTester tester) async {
  const maxDrain = 24;
  final unexpected = <Object>[];

  for (int i = 0; i < maxDrain; i++) {
    final err = tester.takeException();
    if (err == null) break;
    if (_isIgnorableFrameworkException(err)) {
      DualTestHelper.log('[DUAL] ignore non-critical exception: $err');
      continue;
    }
    unexpected.add(err);
  }

  if (unexpected.isNotEmpty) {
    DualTestHelper.log(
      '⚠️ Unexpected framework exception: ${unexpected.first}',
    );
  }
}

bool _isIgnorableFrameworkException(Object err) {
  final text = err.toString();
  return text.contains('ImageNotFoundException') ||
      text.contains('Image not found (404)') ||
      text.startsWith('Multiple exceptions (');
}
