// integration_test/search/web_search_group_click_acceptance_batch169_test.dart
//
// web_search_page「点群组结果进入群聊会话」行解锁（批次169，automation
// 第四十二轮）。原阻塞理由「需本地库群 shadow 行数据」经批次169 复查已
// 不成立：群结果来自**本地 SQLite** GroupRepo.search（title/introduction
// LIKE 匹配 + owner_uid=当前用户 + status=1），并非服务端 fts shadow——
// 而本地群 110610282598107136（IMBoy 产品研发群，批次143 起）服务端早已
// 存在。本批 macOS 容器库为 0 字节空库（近期被重置），测试内用
// GroupRepo.save 本地播种（既定造数实践），其余走真实链路：
//
//   搜索页(/web_search?q=产品研发) → 本地 LIKE 命中 → 群结果 tile →
//   _onItemTap → context.push('/chat/<gid>?type=C2G') → 群聊页渲染
//
//   AT-WS1  搜索关键词命中本地群并渲染群结果项
//   AT-WS1  点群结果进入群聊会话（会话页 AppBar 显示群名）
//
// 运行（define 与批次162 同配方）：
//   flutter test integration_test/search/web_search_group_click_acceptance_batch169_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _groupId = '110610282598107136';
const _groupTitle = 'IMBoy 产品研发群';
const _keyword = '产品研发';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != _uid) {
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区')) ||
        isOnMainShell(tester)) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    } else if (UserRepoLocal.to.currentUid == _uid) {
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go('/bottom_navigation');
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    flowLog('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  await _pump(tester, seconds: 5);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次169：AT-WS1 点群组结果进入群聊会话', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ── 前置：本地播种群行（本地 SQLite 造数，与批次99 同实践）──
    // 服务端同 id 群真实存在（IMBoy 产品研发群，bob 为成员），播种行
    // 仅补齐本地搜索索引；owner_uid 取当前用户以满足 search 的
    // owner_uid=currentUid 过滤（本地造数，不涉及服务端归属）。
    final now = DateTime.now().millisecondsSinceEpoch;
    await GroupRepo().save(_groupId, {
      'id': _groupId,
      'type': 1,
      'join_limit': 1,
      'content_limit': 1,
      'owner_uid': _uid,
      'creator_uid': _uid,
      'member_max': 500,
      'member_count': 2,
      'introduction': 'batch169 本地搜索夹具',
      'avatar': '',
      'title': _groupTitle,
      'status': 1,
      'updated_at': now,
      'created_at': now,
    });
    flowLog('[AT-WS1] 本地群行已播种：$_groupTitle');
    final probe = await GroupRepo().search(kwd: _keyword, limit: 20);
    flowLog('[DIAG] 直接 GroupRepo.search 命中=${probe.length} '
        '首条=${probe.isEmpty ? '无' : probe.first.title}');

    // ── 打开搜索页，输入关键词（UI 输入触发 onChanged 防抖搜索，
    //    规避 push location 中文 query 编码问题）──
    router.push('/web_search');
    final inputReady = await _waitFor(
      tester,
      () => tester.any(find.byType(TextField)),
      seconds: 10,
    );
    expect(inputReady, isTrue, reason: '前置：搜索页应有输入框');
    await tester.enterText(find.byType(TextField).first, _keyword);
    await _pump(tester, seconds: 2);
    // 高亮渲染会把命中词拆成独立 span：标题呈 'IMBoy ￼群' + '产品研发' 分段，
    // 故用 textContaining 命中关键词片段而非完整群名
    final resultShown = await _waitFor(
      tester,
      () => tester.any(find.textContaining(_keyword)),
      seconds: 15,
    );
    if (!resultShown) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      flowLog('[DIAG] 搜索无果可见文本: $texts');
    }
    expect(
      resultShown,
      isTrue,
      reason: 'AT-WS1：搜索「$_keyword」应命中本地群并渲染群结果项',
    );
    flowLog('[AT-WS1] 群结果已渲染');

    // ── 核心断言：点群结果进入群聊会话 ──
    // 注意：标题命中词片段（产品研发）是高亮 span，自带手势会吞掉点击，
    // 改点同行的副标题文本（introduction，无高亮手势）触发行 onTap
    await tester.tap(find.text('batch169 本地搜索夹具'), warnIfMissed: false);
    final chatShown = await _waitFor(
      tester,
      // 搜索页仍在栈下（push 不离栈）；聊天页锚点=AppBar 群名(含成员数) +
      // 输入框占位符「说点什么...」（send_button 仅在输入文字后出现）
      () =>
          tester.any(find.textContaining('产品研发')) &&
          tester.any(find.text('说点什么...')),
      seconds: 20,
    );
    if (!chatShown) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      final hasSend = tester.any(find.byKey(const Key('send_button')));
      flowLog('[DIAG] 点击后可见文本: $texts; send_button=$hasSend');
    }
    expect(
      chatShown,
      isTrue,
      reason:
          'AT-WS1：点群结果应 push /chat/$_groupId?type=C2G 进入群聊会话'
          '（发送按钮+AppBar 群名可辨）',
    );
    flowLog('[AT-WS1] PASS：已进入群聊会话（群名可见）');
  });
}
