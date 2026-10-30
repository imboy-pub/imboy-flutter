// J18.f C2C UI slice: one explicitly prepared synthetic fixture per invocation.
//
// Before running, provision an isolated loopback backend and an isolated test
// account. Seed a recent quote with J18F_QUOTE_ID referencing J18F_TARGET_ID,
// which must not be in the initial chat window. Prepare the target on the
// server for exactly one J18F_CASE: authorized, expired or
// missing_key. The missing-key fixture must use real E2EE ciphertext without
// the key on this device. No production account, service or data may be used.
//
// Use adb reverse (or the equivalent device tunnel) so API_BASE_URL,
// API_BASE_URL_OVERRIDE and WS_URL_OVERRIDE resolve to the isolated service
// on device loopback. Supply APP_ENV=local and
// TEST_PHONE, TEST_PASSWORD, TEST_EXPECTED_UID, PEER_UID, PEER_TITLE,
// J18F_QUOTE_ID, J18F_TARGET_ID, J18F_CASE and
// J18F_ALLOW_ISOLATED_FIXTURE=true as dart-defines. This script does not create
// fixtures, change the clock, delete keys or change permissions. Each case is
// a separate run. A server-side receipt for the requested target and actual
// authorization result is also required: background history sync can race
// the tap, so the UI result alone does not prove the context request path.
// For expired and missing-key cases, separately inspect the isolated SQLite
// and server evidence for unauthorized writes and actual authorization/key
// conditions; absence from the displayed message list does not prove these.
// An unloaded expired target currently produces the generic unavailable
// response. Its fixture needs server-side expiry evidence; the generic UI
// cannot prove that expiry and denial are distinguished.
// C2G forbidden and the full J18.f acceptance require separate evidence;
// a synthetic C2C 403 must not stand in for group membership revocation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/chat/message_quote_builder.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _allow = bool.fromEnvironment('J18F_ALLOW_ISOLATED_FIXTURE');
const _case = String.fromEnvironment('J18F_CASE');
const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerUid = String.fromEnvironment('PEER_UID');
const _peerTitle = String.fromEnvironment('PEER_TITLE');
const _quoteId = String.fromEnvironment('J18F_QUOTE_ID');
const _targetId = String.fromEnvironment('J18F_TARGET_ID');
const _apiUrl = String.fromEnvironment('API_BASE_URL');
const _apiOverride = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const _wsUrl = String.fromEnvironment('WS_URL_OVERRIDE');
const _appEnv = String.fromEnvironment('APP_ENV');
const _phone = String.fromEnvironment('TEST_PHONE');
const _password = String.fromEnvironment('TEST_PASSWORD');
const _allowWrites = bool.fromEnvironment('TEST_ALLOW_BUSINESS_WRITES');

bool _loopback(Uri? uri, Set<String> schemes) =>
    uri != null &&
    schemes.contains(uri.scheme) &&
    const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host) &&
    uri.userInfo.isEmpty;

Future<bool> _poll(WidgetTester tester, bool Function() predicate) async {
  for (var i = 0; i < 150; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 100));
  }
  return predicate();
}

bool _visibleInScrollable(WidgetTester tester, Finder item) {
  if (!tester.any(item)) return false;
  final scroll = find.ancestor(of: item, matching: find.byType(Scrollable));
  if (!tester.any(scroll)) return false;
  final itemRect = tester.getRect(item.first);
  final scrollRect = tester.getRect(scroll.first);
  return itemRect.overlaps(scrollRect) &&
      itemRect.overlaps(
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio,
      );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J18.f fixture: $_case', (tester) async {
    final api = Uri.tryParse(_apiUrl);
    final apiOverride = Uri.tryParse(_apiOverride);
    final ws = Uri.tryParse(_wsUrl);
    if (!_allow ||
        !_allowWrites ||
        _appEnv != 'local' ||
        _phone.isEmpty ||
        _password.isEmpty ||
        !_loopback(api, const {'http', 'https'}) ||
        !_loopback(apiOverride, const {'http', 'https'}) ||
        api!.origin != apiOverride!.origin ||
        !_loopback(ws, const {'ws', 'wss'}) ||
        !const {'authorized', 'expired', 'missing_key'}.contains(_case) ||
        [
          _expectedUid,
          _peerUid,
          _peerTitle,
          _quoteId,
          _targetId,
        ].any((s) => s.isEmpty) ||
        _expectedUid == _peerUid ||
        _quoteId == _targetId) {
      fail('J18.f 需要显式隔离合成环境、loopback API/WS、写入授权、账号及目标 fixture');
    }

    final selected = Uri.tryParse(envMap[_appEnv]!.apiBaseUrl);
    if (!_loopback(selected, const {'http', 'https'}) ||
        selected!.origin != api.origin) {
      fail('App 配置未绑定到指定的 loopback API，不启动应用');
    }

    final chat = await openC2CWithPeer(
      tester,
      journey: 'J18.f',
      expectedUid: _expectedUid,
      peerUid: _peerUid,
      peerTitle: _peerTitle,
    );
    final actual = Uri.tryParse(Env().apiBaseUrl);
    if (!_loopback(actual, const {'http', 'https'}) ||
        actual!.origin != api.origin) {
      fail('运行中的 API 来源与显式隔离 fixture 不一致');
    }
    if (_case == 'missing_key' &&
        !AppFeatureRegistry.isEnabled(FeatureKeys.e2ee)) {
      fail('缺钥场景需要当前构建启用 E2EE 功能位');
    }

    final container = ProviderScope.containerOf(tester.element(chat));
    final notifier = container.read(chatProvider.notifier);
    final quote = find.byWidgetPredicate(
      (widget) =>
          widget is QuoteMessageBuilder && widget.message.id == _quoteId,
    );
    if (!await _poll(tester, () => tester.any(quote))) {
      fail('未加载指定引用消息；请核对独立 fixture 与初始窗口');
    }
    final quoteWidget = tester.widget<QuoteMessageBuilder>(quote.first);
    final quoteData = quoteWidget.message.metadata?['quote_msg'];
    if (quoteData is! Map || quoteData['id']?.toString() != _targetId) {
      fail('fixture 引用目标与 J18F_TARGET_ID 不符');
    }
    if (notifier.chatService?.messages.any((m) => m.id == _targetId) != false) {
      fail('目标已在初始窗口或聊天服务未就绪，不能证明未加载场景');
    }

    final tapTarget = find.descendant(
      of: quote.first,
      matching: find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.onTap != null,
      ),
    );
    expect(tapTarget, findsOneWidget, reason: 'fixture 引用条须可点击');
    await tester.ensureVisible(tapTarget);
    if (notifier.chatService?.messages.any((m) => m.id == _targetId) != false) {
      fail('滚动引用条时目标已加载，不能证明未加载场景');
    }
    await tester.tap(tapTarget);
    await tester.pump();

    final target = find.byWidgetPredicate(
      (widget) => widget is ChatMessageItem && widget.message.id == _targetId,
    );
    if (_case == 'authorized') {
      expect(
        await _poll(tester, () => _visibleInScrollable(tester, target)),
        isTrue,
        reason: '有权的未加载目标必须经历史上下文载入并滚入可见区域',
      );
    } else {
      final expected = switch (_case) {
        'expired' => t.common.quoteMessageUnavailable,
        'missing_key' => t.chat.e2eeRecoveryDecryptFailedTitle,
        _ => throw StateError('invalid J18.f case'),
      };
      expect(
        await _poll(tester, () => tester.any(find.text(expected))),
        isTrue,
        reason: '$_case 必须显示对应的可行动反馈',
      );
      expect(
        notifier.chatService?.messages.any((m) => m.id == _targetId),
        isFalse,
        reason: '不可访问的目标不能进入可显示消息列表',
      );
    }
    await takeScreenshot(tester, 'j18f_$_case');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
