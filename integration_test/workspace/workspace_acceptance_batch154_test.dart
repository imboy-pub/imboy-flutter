// integration_test/workspace/workspace_acceptance_batch154_test.dart
//
// Workspace 域三行阻塞解锁验收（批次154，配方同 workspace_invite_relations_test）：
//
//   AT-WCL1 创建工作区服务端 409 上限错误 toast 透出
//     （workspace_create_page 台账行「服务端错误 toast 原样透出服务端消息」，
//      批次W2R3 起阻塞「造 100 工作区不经济」——本批以 API 循环建 97 个
//      fixture（AT-WS-LIM154-1..97，three_second_once 节流 3.3s 间隔）解锁）
//   AT-WIV2 模板资源定位失败时对应勾选项禁用并提示不可用
//     （workspace_invite_page 台账行；fixture=AT-WS-空区-115 本就 0 群 0 频道，
//      无需 DB 改动）
//   AT-WIV3 工作区邀请失败时整单失败，可选关系不再发起
//     （workspace_invite_page 台账行；adapterForTest 拦 members/invite 注入
//      失败，wire 计数证明 group_member/join 与 channel 邀请从未发出）
//
// 载体：smoke_bob（uid=1000000056）；被邀人 smoke_alice（uid=1000000051）。
// 红线：仅本地（9801/4323）；不触碰真人。
//
// 运行（配方同 workspace_invite_relations_test）：
//   flutter test integration_test/workspace/workspace_acceptance_batch154_test.dart \
//     -d <device> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_PHONE=smoke_bob \
//     --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CheckboxListTile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/workspace/workspace_create_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_invite_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _inviteeUid = '1000000051'; // SmokeAlice
const _wsEmpty = '100000000000000210'; // AT-WS-空区-115（0 群 0 频道）
const _wsLim = '111720650783328256'; // AT-WS-LIM154-1（Template 齐全）
const _announcementsChannelOfT27 = '110073884407236608';
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_WORKSPACE_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

/// 三路径计数 + invite 失败注入适配器：
/// - failWsInvite=true 时 /members/invite 返回业务失败（AT-WIV3）
/// - 计数器证明可选关系在主失败后从未发起（wire 级铁证）
class _CountAdapter implements HttpClientAdapter {
  _CountAdapter()
    : _inner = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());

  final HttpClientAdapter _inner;
  bool failWsInvite = false;
  int inviteN = 0;
  int groupJoinN = 0;
  int channelInvN = 0;
  int groupsN = 0;
  int channelsN = 0;

  ResponseBody _fail(String msg) => ResponseBody.fromString(
    jsonEncode(<String, dynamic>{
      'code': 1,
      'msg': msg,
      'payload': <String, dynamic>{},
    }),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final p = options.uri.path;
    if (p.contains('/workspaces/') && p.endsWith('/members/invite')) {
      inviteN++;
      if (failWsInvite) {
        flowLog('[AT-WIV3] 拦截 members/invite（注入失败）');
        return _fail('simulated_ws_invite_down');
      }
    } else if (p.contains('/group_member/join')) {
      groupJoinN++;
    } else if (p.contains('/invitation')) {
      channelInvN++;
    } else if (p.endsWith('/groups')) {
      groupsN++;
      final r = await _inner.fetch(options, requestStream, cancelFuture);
      final bytes = await r.stream.expand((b) => b).toList();
      flowLog(
        '[诊断] groups(#$groupsN $p) status=${r.statusCode} '
        'body=${utf8.decode(bytes, allowMalformed: true)}',
      );
      return ResponseBody.fromBytes(bytes, r.statusCode, headers: r.headers);
    } else if (p.endsWith('/channels')) {
      channelsN++;
      flowLog('[诊断] channels(#$channelsN $p)');
    }
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _inner.close(force: force);
  }
}

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

Future<void> _bootAndRelogin(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  if (UserRepoLocal.to.currentUid.isNotEmpty) {
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 4);
    await Future<void>.delayed(const Duration(seconds: 4));
    await _pump(tester, seconds: 2);
  }
  const loginSubmit = Key('login_submit_button');
  for (var i = 0; i < 8; i++) {
    if (UserRepoLocal.to.currentUid == _expectedUid && isOnMainShell(tester)) {
      return;
    }
    if (tester.any(find.byKey(loginSubmit))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    }
    await _pump(tester, seconds: 6);
  }
  expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');
}

/// 向导页搜索并选中 smoke_alice（批次152 收口配方：控制器直写 +
/// done 提交 + 搜索按钮双 tap 兜底）。
Future<void> _searchAndSelect(WidgetTester tester) async {
  final fieldEt = tester.widget<EditableText>(
    find.descendant(
      of: find.byType(WorkspaceInvitePage),
      matching: find.byType(EditableText),
    ),
  );
  fieldEt.controller.text = 'smoke_alice';
  await _pump(tester, seconds: 1);
  try {
    await tester.testTextInput
        .receiveAction(TextInputAction.done)
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    flowLog('[批次154] done action 失败/超时：$e');
  }
  await _pump(tester, seconds: 3);
  final searchBtn = find.descendant(
    of: find.byType(WorkspaceInvitePage),
    matching: find.byKey(const ValueKey('workspace-invite-search-btn')),
  );
  if (tester.any(searchBtn)) {
    await tester.tap(searchBtn.first, warnIfMissed: false);
    await _pump(tester, seconds: 3);
    await tester.tap(searchBtn.first, warnIfMissed: false);
    await _pump(tester, seconds: 3);
  }
  final candidate = find.byKey(
    const ValueKey('workspace-invite-candidate-$_inviteeUid'),
  );
  expect(
    await _waitFor(tester, () => tester.any(candidate), seconds: 8),
    isTrue,
    reason: '前置：候选 smoke_alice 出现',
  );
  await tester.tap(candidate.first, warnIfMissed: false);
  await _pump(tester, seconds: 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次154：AT-WCL1 + AT-WIV2 + AT-WIV3', (tester) async {
    expect(
      _allow,
      isTrue,
      reason: '需要 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true 显式放行（业务写入红线）',
    );

    await _bootAndRelogin(tester);
    flowLog('[批次154] 登录完成 uid=${UserRepoLocal.to.currentUid}');

    // ───────── AT-WIV3 前置清理：往轮遗留的 T27 频道邀请 ─────────
    await TestPg.execute(
      'DELETE FROM channel_invitation '
      'WHERE channel_id = @c AND invitee_uid = @u',
      {'c': _announcementsChannelOfT27, 'u': _inviteeUid},
    );
    // run7 污染防御：往轮真实 invite 可能残留 alice 成员行（幂等 invite
    // 会把注入场景误判成真实成功），前置一律清空
    await TestPg.execute(
      'DELETE FROM workspace_member '
      'WHERE workspace_id = @w AND user_id = @u',
      {'w': _wsLim, 'u': _inviteeUid},
    );
    await TestPg.execute(
      'DELETE FROM group_member WHERE user_id = @u AND group_id IN '
      '(SELECT id FROM "group" WHERE workspace_id = @w)',
      {'w': _wsLim, 'u': _inviteeUid},
    );

    // ══════════ AT-WCL1：创建页 409 上限 toast 透出 ══════════
    // 前置：bob active 工作区已建满 100（MAX_WORKSPACES_PER_OWNER）
    final cnt = int.parse(
      '${await TestPg.scalar("SELECT count(*) FROM workspace "
      "WHERE owner_id = 1000000056 AND status = 'active'")}',
    );
    flowLog('[AT-WCL1] bob active 工作区数=$cnt');
    expect(cnt, 100, reason: '前置：必须已建满上限 100（API fixture，批次154 准备步）');

    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/workspace/create');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WorkspaceCreatePage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：创建页可达',
    );

    final nameField = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(WorkspaceCreatePage),
        matching: find.byType(EditableText),
      ),
    );
    nameField.controller.text = 'AT-WS-LIM154-over';
    await _pump(tester, seconds: 1);

    await tester.tap(
      find.byKey(const ValueKey('workspace-create-submit')),
      warnIfMissed: false,
    );
    // 等 409 往返 + toast 弹出（EasyLoading displayDuration 3s 窗口内）
    final toastSeen = await _waitFor(
      tester,
      () => tester.any(find.textContaining('已达工作区创建上限')),
      seconds: 4,
    );
    expect(
      toastSeen,
      isTrue,
      reason: 'AT-WCL1：服务端 409 消息「已达工作区创建上限」须 toast 透出',
    );
    flowLog('[AT-WCL1] ✓ toast 文本已在 widget 树捕获');

    // 行为断言：不跳转 Overview（页面仍在）+ 计数未变（写被拒）
    expect(
      tester.any(find.byType(WorkspaceCreatePage)),
      isTrue,
      reason: 'AT-WCL1：失败后停留创建页，不进入 Overview',
    );
    final cnt2 = int.parse(
      '${await TestPg.scalar("SELECT count(*) FROM workspace "
      "WHERE owner_id = 1000000056 AND status = 'active'")}',
    );
    expect(cnt2, 100, reason: 'AT-WCL1：被拒后 active 工作区数不变');

    // wire 主判据：测试内同参数直发，锚定服务端 envelope（节流窗 3s 后）
    await Future<void>.delayed(const Duration(seconds: 4));
    final resp = await HttpClient.client.post(
      '/api/v1/workspaces',
      data: <String, dynamic>{
        'name': 'AT-WS-LIM154-over2',
        'request_id': 'at154-over-ui-verify',
      },
    );
    expect(resp.ok, isFalse, reason: 'AT-WCL1：超限创建必须失败');
    expect(resp.code, 409, reason: 'AT-WCL1：envelope code=409');
    expect(resp.msg, '已达工作区创建上限', reason: 'AT-WCL1：服务端消息与 toast 文案同源');
    flowLog('[AT-WCL1] ✓ wire: code=${resp.code} msg=${resp.msg}');
    flowLog('[AT-WCL1] ── PASS ──');

    // ══════════ AT-WIV2：空区工作区勾选项禁用 + 不可用提示 ══════════
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/workspace/$_wsEmpty/members/invite');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WorkspaceInvitePage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：空区邀请向导可达',
    );
    await _pump(tester, seconds: 2); // 等 _locateTemplateResources 完成
    await _searchAndSelect(tester);

    final joinGroupTile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('workspace-invite-join-group')),
    );
    final subChannelTile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('workspace-invite-subscribe-channel')),
    );
    expect(
      joinGroupTile.onChanged,
      isNull,
      reason: 'AT-WIV2：无 General 群时「加入群」勾选必须禁用',
    );
    expect(
      subChannelTile.onChanged,
      isNull,
      reason: 'AT-WIV2：无 Announcements 频道时「订阅频道」勾选必须禁用',
    );
    final unavailable = find.textContaining('不可用');
    expect(tester.any(unavailable), isTrue, reason: 'AT-WIV2：禁用项须带「不可用」副标题提示');
    flowLog('[AT-WIV2] ✓ 两勾选禁用 + 副标题命中 ${tester.any(unavailable)}');
    flowLog('[AT-WIV2] ── PASS ──');

    // ══════════ AT-WIV3：主邀请失败 → 可选关系不发起 ══════════
    final adapter = _CountAdapter()..failWsInvite = true;
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    // keepAlive 陷阱（run7 定案）：workspaceApiProvider 常驻，WIV2 场景
    // 已构造实例（装原 adapter）；静态 adapterForTest 只在 HttpClient
    // 构造时生效——必须 invalidate 让 ref.read 重建 WorkspaceApi，
    // 否则主邀请绕过注入真实打到服务端（run7 实证并已清污：
    // smoke_alice 真实入区/入群各一行）。
    ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ).invalidate(workspaceApiProvider);

    // dio 通道探针：adapter 装上后主 client 是否仍可用（排除注入污染）
    final probe = await HttpClient.client
        .get('/api/v1/workspaces/$_wsLim/groups')
        .timeout(const Duration(seconds: 8));
    flowLog(
      '[诊断] 探针 groups: ok=${probe.ok} code=${probe.code} '
      'msg=${probe.msg}',
    );

    // go_router 行为（run5 定案）：同路由分支仅参数变化（空区→LIM）时
    // go() 不重建 onstage 页面（实例 workspaceId 保持旧值、initState 不重跑
    // →_locateTemplateResources 零请求→勾选保持禁用）。解法：先回主壳
    // 再导航（WIV1 配方：从主壳 go 向导一次成功）。
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/bottom_navigation');
    await _pump(tester, seconds: 2);
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/workspace/$_wsLim/members/invite');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WorkspaceInvitePage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：LIM154-1 邀请向导可达',
    );
    // 防回归断言：onstage 实例必须是目标工作区（run5 曾打到空区旧实例）
    final wizardOnStage = tester.widget<WorkspaceInvitePage>(
      find.byType(WorkspaceInvitePage),
    );
    expect(
      wizardOnStage.workspaceId.toString(),
      _wsLim,
      reason: '前置：向导实例必须绑定 LIM154-1（go 换页防回归）',
    );
    flowLog('[AT-WIV3] onstage 向导 workspaceId=${wizardOnStage.workspaceId}');
    await _searchAndSelect(tester);

    // 前置：两项可勾选（Template 齐全）——轮询等待 initState 的
    // _locateTemplateResources 网络往返完成（run2 教训：固定 pump 2s
    // 与真机网络时序竞态，断言读到定位前的空 id）
    bool tilesReady = false;
    for (var i = 0; i < 16 && !tilesReady; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        final join = tester.widget<CheckboxListTile>(
          find.byKey(const ValueKey('workspace-invite-join-group')),
        );
        final sub = tester.widget<CheckboxListTile>(
          find.byKey(const ValueKey('workspace-invite-subscribe-channel')),
        );
        tilesReady = join.onChanged != null && sub.onChanged != null;
      } on Object {
        // tile 未渲染（候选人未选中/多实例）→ 继续等
      }
    }
    flowLog(
      '[AT-WIV3] 资源定位轮询: ready=$tilesReady '
      'groupsN=${adapter.groupsN} channelsN=${adapter.channelsN}',
    );
    final joinGroupTile3 = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('workspace-invite-join-group')),
    );
    final subChannelTile3 = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('workspace-invite-subscribe-channel')),
    );
    expect(
      joinGroupTile3.onChanged,
      isNotNull,
      reason: '前置：LIM154-1 有 General 群，勾选应可用',
    );
    expect(
      subChannelTile3.onChanged,
      isNotNull,
      reason: '前置：LIM154-1 有 Announcements 频道，勾选应可用',
    );

    adapter.groupJoinN = 0;
    adapter.channelInvN = 0;
    // 提交按钮在 ListView 底部：须先滚动可见，否则 tap 被静默吞掉（run6）
    final submitFinder = find.byKey(const ValueKey('workspace-invite-submit'));
    await tester.ensureVisible(submitFinder);
    await _pump(tester, seconds: 1);
    await tester.tap(submitFinder, warnIfMissed: false);
    // 等主失败往返 + 整单终止
    await _pump(tester, seconds: 6);
    expect(adapter.inviteN, 1, reason: 'AT-WIV3：主邀请恰发一次（被注入失败）');
    expect(
      adapter.groupJoinN,
      0,
      reason: 'AT-WIV3：主失败后 group_member/join 必须不发起',
    );
    expect(adapter.channelInvN, 0, reason: 'AT-WIV3：主失败后频道邀请必须不发起');
    expect(
      tester.any(find.byType(WorkspaceInvitePage)),
      isTrue,
      reason: 'AT-WIV3：失败后停留向导页（结果区呈现失败态）',
    );
    flowLog(
      '[AT-WIV3] ✓ invite=${adapter.inviteN} groupJoin=${adapter.groupJoinN} '
      'channelInv=${adapter.channelInvN}',
    );
    flowLog('[AT-WIV3] ── PASS ──');
  });
}
