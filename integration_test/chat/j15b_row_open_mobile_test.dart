// integration_test/chat/j15b_row_open_mobile_test.dart
//
// plan-v2.2 §9 J15.b 移动壳脚本（Android 真机；桌面壳另见
// j15b_row_open_desktop_test.dart）。
//
// 断言（§9 J15.b）：C2C、C2G 分别，点整行并返回 → 正确 chat type/对象
// 与宿主目的地。移动壳判定单元：
//   m-1 C2C 行：tapAt 整行热区 → push /chat/<peerId>，ChatPage.type='C2C'
//       且 peerId=对端 uid（非头像路由）；pop → 原列表原位（同 Scrollable
//       state、offset 保持、行屏幕坐标保持）
//   m-2 C2G 行：同型，ChatPage.type='C2G' 且 peerId=群 gid
//
// 运行方法（NC 口径，integration_test/README.md）：
//   flutter test integration_test/chat/j15b_row_open_mobile_test.dart \
//     -d <Android serial> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=... \
//     --dart-define=TEST_EXPECTED_UID=<alice uid> \
//     --dart-define=TEST_PEER_ID=<bob uid> \
//     --dart-define=TEST_GROUP_ID=<合成群 gid>
//
// 隔离前置（J16.c 双机批次口径）：仅限合成部署 + 专用演示账号 + 独立
// 设备存储；打开聊天页会触发已读上报与待发队列冲刷，执行前必须确认
// 设备账号与队列隔离（全新安装或专用验收机）。本脚本不发消息、不改
// 偏好，仅做列表导航断言。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

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
  testWidgets('J15.b 移动壳：C2C/C2G 整行点击进正确聊天并返回原位', (tester) async {
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
    expect(await openConversationTab(tester), isTrue);
    await settle(tester, maxSeconds: 2);
    await _visit(tester, generation, 'C2C', _peerId);
    await _visit(tester, generation, 'C2G', _groupId);
    _assertOwner(generation);
    flowLog('J15B_MOBILE_DONE uid=$_expectedUid');
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
    reason: 'macOS/本地直连必须显式 WS_URL_OVERRIDE（J16.c 环境注记）',
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

Future<void> _visit(
  WidgetTester tester,
  int generation,
  String type,
  String id,
) async {
  _assertOwner(generation);
  final list = find.byType(ConversationPage);
  expect(list, findsOneWidget);
  final listElement = tester.element(list);
  final router = GoRouter.of(listElement);
  final scrollView = find.descendant(
    of: list,
    matching: find.byType(CustomScrollView),
  );
  expect(scrollView, findsOneWidget, reason: '定位会话页自身的 CustomScrollView');
  final scroll = find.descendant(
    of: scrollView,
    matching: find.byElementPredicate((element) {
      final widget = element.widget;
      if (widget is! Scrollable || widget.axisDirection != AxisDirection.down) {
        return false;
      }
      ScrollView? nearest;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is ScrollView) {
          nearest = ancestor.widget as ScrollView;
          return false;
        }
        return true;
      });
      return identical(nearest, scrollView.evaluate().first.widget);
    }),
  );
  expect(scroll, findsOneWidget, reason: '排除群头像等嵌套 GridView');
  final row = _row(type, id);
  // 真实列表惰性构建：从顶端滚动查找目标行
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(row, 180, scrollable: scroll);
  await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
  await settle(tester, maxSeconds: 2);
  final position = tester.state<ScrollableState>(scroll).position;
  if (position.pixels == 0 && position.maxScrollExtent > 0) {
    position.jumpTo(24.0.clamp(0.0, position.maxScrollExtent));
    await settle(tester, maxSeconds: 1);
  }
  final offset = position.pixels;
  final rect = tester.getRect(row);
  // 整行热区：行中线偏右 40px（头像热区在左侧 16+56px 内，右侧为角标）
  final center = tester.getCenter(row);
  await tester.tapAt(Offset(center.dx + 40, center.dy));
  await settle(tester, maxSeconds: 4);
  // 宿主目的地 = push 的 ChatPage，type/对象来自所点行
  final chat = find.byType(ChatPage);
  expect(chat, findsOneWidget, reason: '$type 整行应进入聊天页');
  final chatWidget = tester.widget<ChatPage>(chat);
  expect(chatWidget.type, type, reason: 'chat type 必须与所点会话行一致');
  expect(chatWidget.peerId, id, reason: '聊天对象必须与所点会话行 peerId 一致');
  expect(
    GoRouter.of(tester.element(chat))
        .routerDelegate
        .currentConfiguration
        .uri
        .path,
    '/chat/$id',
    reason: '宿主目的地路由应为 /chat/<peerId>',
  );
  _assertOwner(generation);
  expect(router.canPop(), isTrue);
  router.pop();
  await settle(tester, maxSeconds: 3);
  expect(find.byType(ChatPage), findsNothing);
  expect(tester.element(list), same(listElement), reason: '返回原列表而非重建');
  expect(tester.state<ScrollableState>(scroll).position, same(position));
  expect(position.pixels, closeTo(offset, 0.5), reason: 'pop 不得重置 offset');
  final after = tester.getRect(row);
  expect(after.left, closeTo(rect.left, 0.5));
  expect(after.top, closeTo(rect.top, 0.5), reason: '原身份行屏幕坐标应保持');
  expect(after.size, rect.size);
  _assertOwner(generation);
  flowLog('J15B_MOB_OK type=$type id=$id offset=$offset');
}
