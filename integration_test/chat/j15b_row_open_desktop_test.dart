// integration_test/chat/j15b_row_open_desktop_test.dart
//
// plan-v2.2 §9 J15.b 桌面壳脚本（macOS App，宽屏 Web Shell 三栏宿主；
// 移动壳另见 j15b_row_open_mobile_test.dart）。
//
// 断言（§9 J15.b）：C2C、C2G 分别，点整行并返回 → 正确 chat type/对象
// 与宿主目的地。桌面壳判定单元（宿主目的地 = Web Shell 右栏派发，不
// push 独立 /chat 路由）：
//   d-1 C2C 行：tapAt 整行热区 → webShellProvider.selectedItem 为
//       ChatSelection(peerId=<bob uid>, chatType='C2C')；列表未离开、
//       行仍可命中；无移动端 ChatPage 路由 push
//   d-2 C2G 行：同型，ChatSelection(peerId=<群 gid>, chatType='C2G')
//
// 运行方法（NC 口径，integration_test/README.md；macOS 构建后运行）：
//   flutter test integration_test/chat/j15b_row_open_desktop_test.dart \
//     -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=... \
//     --dart-define=TEST_EXPECTED_UID=<alice uid> \
//     --dart-define=TEST_PEER_ID=<bob uid> \
//     --dart-define=TEST_GROUP_ID=<合成群 gid>
//
// 环境注记（J16.c 双机批次先例）：macOS 本地直连必须显式
// WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws——App 本地默认 /ws 路径
// 404，真实路由为 /api/v1/ws。桌面 App 全新安装即独立设备存储。
//
// 隔离前置：仅限合成部署 + 专用演示账号；本脚本不发消息、不改偏好，
// 仅做列表导航与右栏派发断言。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/web_shell/web_shell_provider.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerId = String.fromEnvironment('TEST_PEER_ID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _appEnv = String.fromEnvironment('APP_ENV');
const _apiOverride = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const _wsOverride = String.fromEnvironment('WS_URL_OVERRIDE');
const _localApi = 'http://127.0.0.1:9800';
const _localWs = 'ws://127.0.0.1:9800/api/v1/ws';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('J15.b 桌面壳：C2C/C2G 整行派发右栏 ChatSelection', (tester) async {
    // 宽屏断点 900px（AppBreakpoints.wide）：flutter test 默认窗口不满足
    // useSplitView 双栏条件，显式拉大视口（dp）。
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    if (!requireBusinessWriteAuthorization()) return;
    _validateConfig();
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J15.b 登录/环境前置失败');
    }
    final generation = UserRepoLocal.to.sessionGeneration;
    _assertOwner(generation);
    await dismissRecoveryGuide(tester);
    await dismissUpgradeDialog(tester);
    await dismissE2eeBackupSetupPage(tester);
    // 桌面 Web Shell 默认 currentTab=0 会话；等待中栏会话列表挂载。
    // （不使用 openConversationTab——桌面壳无底部导航。）
    final list = find.byType(ConversationPage);
    var mounted = false;
    for (var i = 0; i < 30 && !mounted; i++) {
      mounted = list.evaluate().isNotEmpty;
      if (!mounted) await settle(tester, maxSeconds: 1);
    }
    expect(mounted, isTrue, reason: '桌面 Web Shell 默认应挂载会话列表');
    await settle(tester, maxSeconds: 2);
    await _select(tester, generation, 'C2C', _peerId);
    await _select(tester, generation, 'C2G', _groupId);
    _assertOwner(generation);
    flowLog('J15B_DESKTOP_DONE uid=$_expectedUid');
  }, timeout: const Timeout(Duration(minutes: 6)));
}

void _validateConfig() {
  final id = RegExp(r'^[1-9][0-9]*$');
  expect(id.hasMatch(_expectedUid), isTrue, reason: '显式 TEST_EXPECTED_UID');
  expect(id.hasMatch(_peerId), isTrue, reason: '显式 TEST_PEER_ID');
  expect(id.hasMatch(_groupId), isTrue, reason: '显式 TEST_GROUP_ID');
  expect(_peerId, isNot(_expectedUid), reason: 'C2C 对端不得是自己');
  expect(_groupId, isNot(_expectedUid), reason: '群 gid 不得是自己 uid');
  expect(_appEnv, 'local_office', reason: '必须显式指定 APP_ENV');
  expect(_apiOverride, _localApi, reason: '必须显式指定本机 API override');
  expect(
    _wsOverride,
    _localWs,
    reason: 'macOS 本地直连必须显式 WS_URL_OVERRIDE（J16.c 环境注记）',
  );
}

void _assertOwner(int generation) {
  final user = UserRepoLocal.to;
  expect(user.isLoggedIn, isTrue);
  expect(user.currentUid, _expectedUid, reason: '登录账号不得漂移');
  expect(user.isCurrentSession(generation), isTrue);
  expect(user.isAuthTransitioning, isFalse);
  expect(user.isClearingSession, isFalse);
}

Finder _row(String type, String id) => find.byWidgetPredicate(
  (w) =>
      w is ConversationItem &&
      w.model.type == type &&
      w.model.peerId.toString() == id,
);

Future<void> _select(
  WidgetTester tester,
  int generation,
  String type,
  String id,
) async {
  _assertOwner(generation);
  final list = find.byType(ConversationPage);
  expect(list, findsOneWidget);
  final container = ProviderScope.containerOf(tester.element(list));
  final row = _row(type, id);
  var seen = false;
  for (var i = 0; i < 30 && !seen; i++) {
    seen = tester.any(row);
    if (!seen) await settle(tester, maxSeconds: 1);
  }
  expect(seen, isTrue, reason: '$type 会话应出现在桌面壳会话列表');
  await tester.scrollUntilVisible(
    row,
    180,
    scrollable: find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first,
  );
  await settle(tester, maxSeconds: 2);
  // 整行热区：行中线偏右 40px，避开头像热区
  final center = tester.getCenter(row);
  await tester.tapAt(Offset(center.dx + 40, center.dy));
  await settle(tester, maxSeconds: 3);
  // 宿主目的地 = 右栏 ChatSelection；不 push 移动端聊天路由
  final shell = container.read(webShellProvider);
  final selection = shell.selectedItem;
  expect(selection, isA<ChatSelection>(), reason: '$type 整行应派发右栏选中');
  expect((selection as ChatSelection).peerId, id);
  expect(selection.chatType, type);
  expect(
    find.byType(ChatPage),
    findsNothing,
    reason: '桌面壳宿主目的地是右栏，不得 push 独立聊天路由',
  );
  expect(find.byType(ConversationPage), findsOneWidget, reason: '列表未离开');
  expect(row.hitTestable(), findsOneWidget, reason: '行仍可命中（未导航离开）');
  _assertOwner(generation);
  flowLog('J15B_DESK_OK type=$type id=$id');
}
