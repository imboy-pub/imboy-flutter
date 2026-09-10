// integration_test/channel/channel_subscriber_invite_acceptance_batch170_test.dart
//
// channel_subscriber_page「邀请选人弹层过滤待处理邀请并发送」行解锁（批次170，
// automation 第四十三轮）。原阻塞理由「需私有频道+第二台设备」经批次170
// 复查两点均不成立：
//
//   ① 私有频道可用服务端 API 直接创建（POST /api/v1/channel/create，
//      visibility=1 + access_type=0 + join_policy=1），无需 UI 走创建页；
//   ② 本行被测范围是「弹层过滤 + 发送」，发送后 DB 落 channel_invitation
//      行（status=0 待处理）即为终态证据，被邀请人接受/拒绝属于
//      channel_invitation_page 的行，不需要第二台设备。
//
// 顺带挖出并修复服务端真 bug BUG#149：channel_ds:create_channel 事务只插
// channel+channel_admin 行，不插创建者订阅行，而邀请链路校验真实订阅表
// （channel_logic_invitation:create_invitation → is_subscribed），导致
// 私有邀请制频道的创建者永远无法邀请任何人（「您不是频道订阅者，无法
// 邀请他人」）。修复=创建事务内 upsert_active(创建者)+subscriber_count+1。
// 本测试的 AT-CS2 前置断言（create 返回 subscriber_count==1）即该修复的
// 服务端回归锁；9801 节点已热更验证。
//
// 全链路（除本地联系人播种外全部真实）：
//   API 建私有频道 → push /channel/:id/subscribers(canInvite=true) →
//   FAB → 弹层（getSentInvitations 真实 API → 过滤）→ 点 Alice →
//   sendInvitation 真实 API → DB 断言 channel_invitation(status=0) →
//   再次打开弹层 → Alice 被过滤（空态文案）
//
//   AT-CS2  私有频道创建返回创建者已订阅（BUG#149 服务端回归锁）
//   AT-CS2  邀请弹层展示可邀请联系人并成功发送（DB 落待处理邀请行）
//   AT-CS2  已有待处理邀请的联系人被弹层过滤（空态文案）
//
// 运行（define 与批次169 同配方）：
//   flutter test integration_test/channel/channel_subscriber_invite_acceptance_batch170_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _baseUrl = 'http://127.0.0.1:9801';
const _inviteeUid = '1000000051'; // smoke_alice（自有测试账号）
const _contactName = 'Alice 邀请夹具';
const _channelNamePrefix = 'batch170-私有邀请频道';

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

/// API 登录 bob，返回 token（配方同 group/face_to_face_acceptance_test）。
Future<String> _apiLogin() async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(
      Uri.parse('$_baseUrl/api/v1/passport/login'),
    );
    req.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    req.write(
      'account=smoke_bob&pwd=admin888'
      '&rsa_encrypt=0&type=account&did=batch170&cos=macos',
    );
    final res = await req.close();
    final body = jsonDecode(await utf8.decoder.bind(res).join()) as Map;
    if (body['code'] != 0) {
      fail('前置：API 登录失败 ${body['msg']}');
    }
    return (body['payload'] as Map)['token'] as String;
  } finally {
    client.close();
  }
}

/// API 创建私有邀请制频道，返回 channelId。
/// 断言 payload.subscriber_count == 1 —— BUG#149 修复的服务端回归锁：
/// 修复前创建者无订阅行，subscriber_count=0 且后续邀请必被拒。
Future<String> _apiCreatePrivateChannel(String token) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(
      Uri.parse('$_baseUrl/api/v1/channel/create'),
    );
    req.headers.set('authorization', token);
    req.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    req.write(
      'name=${Uri.encodeQueryComponent(_channelNamePrefix)}'
      '&visibility=1&access_type=0&join_policy=1'
      '&description=${Uri.encodeQueryComponent('批次170 邀请行夹具')}',
    );
    final res = await req.close();
    final body = jsonDecode(await utf8.decoder.bind(res).join()) as Map;
    if (body['code'] != 0) {
      fail('前置：创建私有频道失败 ${body['msg']}（注意频道创建上限 20）');
    }
    final payload = body['payload'] as Map;
    final subCount = payload['subscriber_count'];
    expect(
      int.tryParse('$subCount') ?? subCount,
      1,
      reason:
          'AT-CS2/BUG#149：创建私有频道后创建者应即为订阅者'
          '（subscriber_count=1，修复前为 0）',
    );
    return payload['id'].toString();
  } finally {
    client.close();
  }
}

Future<void> _cleanup(int? keepChannelId) async {
  // 清理历史 batch170 残留（保留当前用例频道待最后统一删）
  await TestPg.execute(
    "DELETE FROM channel_invitation WHERE channel_id IN "
    "(SELECT id FROM channel WHERE name LIKE 'batch170%')",
  );
  await TestPg.execute(
    "DELETE FROM channel_subscription WHERE channel_id IN "
    "(SELECT id FROM channel WHERE name LIKE 'batch170%')",
  );
  await TestPg.execute(
    "DELETE FROM channel_admin WHERE channel_id IN "
    "(SELECT id FROM channel WHERE name LIKE 'batch170%')",
  );
  await TestPg.execute("DELETE FROM channel WHERE name LIKE 'batch170%'");
  // 清 bob 全部已发邀请（getSentInvitations 是 inviter 维度，防历史 pending 污染过滤断言）
  await TestPg.execute(
    'DELETE FROM channel_invitation WHERE inviter_uid = @uid',
    {'uid': int.parse(_uid)},
  );
  if (keepChannelId != null) {
    await TestPg.execute(
      'DELETE FROM channel_invitation WHERE channel_id = @ch',
      {'ch': keepChannelId},
    );
    await TestPg.execute(
      'DELETE FROM channel_subscription WHERE channel_id = @ch',
      {'ch': keepChannelId},
    );
    await TestPg.execute('DELETE FROM channel_admin WHERE channel_id = @ch', {
      'ch': keepChannelId,
    });
    await TestPg.execute('DELETE FROM channel WHERE id = @ch', {
      'ch': keepChannelId,
    });
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次170：AT-CS2 邀请弹层过滤待处理邀请并发送', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ── 前置：清理历史夹具（防创建上限 20 / pending 邀请污染）──
    await _cleanup(null);

    // ── 前置：API 建私有邀请制频道（含 BUG#149 回归断言）──
    final token = await _apiLogin();
    final channelId = await _apiCreatePrivateChannel(token);
    flowLog('[AT-CS2] 私有频道已建：$channelId（创建者已订阅）');

    // ── 前置：本地播种好友联系人（弹层候选来自本地 contact 表
    //    ContactRepo.findFriend，user_id=currentUid AND is_friend=1；
    //    本地造数，不触服务端好友关系）──
    await ContactRepo().insert(
      ContactModel(
        peerId: int.parse(_inviteeUid),
        nickname: _contactName,
        account: 'smoke_alice',
        isFriend: 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final friends = await ContactRepo().findFriend();
    flowLog('[AT-CS2] 本地好友候选=${friends.length}');

    // ── 打开订阅者管理页（extra.canInvite=true 与频道详情页
    //    manage_subscribers 出口同参；该出口判定已在批次69 验过）──
    router.push('/channel/$channelId/subscribers', extra: {'canInvite': true});
    final pageReady = await _waitFor(
      tester,
      () => tester.any(find.textContaining('管理订阅者')),
      seconds: 15,
    );
    expect(pageReady, isTrue, reason: '前置：订阅者管理页应打开（标题「管理订阅者」）');
    // 路由过渡 + 首屏加载缓冲（批次168 教训：过渡期 tap 会被吞）
    await _pump(tester, seconds: 4);

    // ── AT-CS2a：邀请 FAB 仅 canInvite 时可见，点开弹层 ──
    final fabFinder = find.byTooltip('邀请好友');
    expect(
      tester.any(fabFinder),
      isTrue,
      reason: 'AT-CS2a：canInvite=true 下应渲染「邀请好友」FAB',
    );
    await tester.tap(fabFinder, warnIfMissed: false);
    final sheetReady = await _waitFor(
      tester,
      () =>
          tester.any(find.text('邀请好友')) && tester.any(find.text(_contactName)),
      seconds: 15,
    );
    if (!sheetReady) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      flowLog('[DIAG] 弹层未现候选，可见文本: $texts');
    }
    expect(
      sheetReady,
      isTrue,
      reason:
          'AT-CS2a：弹层应展示可邀请联系人 $_contactName'
          '（首次无待处理邀请，候选=全量好友）',
    );
    flowLog('[AT-CS2a] PASS：弹层候选含 $_contactName');

    // ── AT-CS2b：点候选人 → 真实 sendInvitation → DB 落待处理邀请行 ──
    await tester.tap(find.text(_contactName), warnIfMissed: false);
    var invitedRow = false;
    for (var i = 0; i < 40 && !invitedRow; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final v = await TestPg.scalar(
        'SELECT status FROM channel_invitation '
        'WHERE channel_id = @ch AND invitee_uid = @invitee',
        {'ch': int.parse(channelId), 'invitee': int.parse(_inviteeUid)},
      );
      invitedRow = v != null && '$v' == '0';
    }
    expect(
      invitedRow,
      isTrue,
      reason:
          'AT-CS2b：发送邀请应真实落库 channel_invitation'
          '（channel=$channelId, invitee=$_inviteeUid, status=0 待处理）',
    );
    flowLog('[AT-CS2b] PASS：邀请已发送并落库（status=0）');
    // 弹层已随 pop 关闭，回到订阅者页；缓冲让 toast 消失、状态复位
    await _pump(tester, seconds: 5);

    // ── AT-CS2c：再次打开弹层，待处理邀请人被过滤 ──
    // _showInviteContactPicker 先 getSentInvitations（真实 API）→
    // extractPendingInviteeIds(status=0) → filterContactsForInvitation
    // 剔除 alice → 候选为空 → 空态「所有好友都已被邀请或已订阅」
    final fab2 = find.byTooltip('邀请好友');
    expect(tester.any(fab2), isTrue, reason: '前置：二次打开前 FAB 仍在');
    await tester.tap(fab2, warnIfMissed: false);
    final filtered = await _waitFor(
      tester,
      () => tester.any(find.text('所有好友都已被邀请或已订阅')),
      seconds: 15,
    );
    if (!filtered) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      final aliceStill = tester.any(find.text(_contactName));
      flowLog('[DIAG] 过滤断言未现空态，可见文本: $texts; aliceStill=$aliceStill');
    }
    expect(
      filtered,
      isTrue,
      reason:
          'AT-CS2c：已有待处理邀请的 $_contactName 应被弹层过滤'
          '（候选空 → 空态「所有好友都已被邀请或已订阅」）',
    );
    expect(
      tester.any(find.text(_contactName)),
      isFalse,
      reason: 'AT-CS2c：待处理邀请人不应再出现在候选列表',
    );
    flowLog('[AT-CS2c] PASS：待处理邀请人已被过滤（空态文案）');
    await _pump(tester, seconds: 2);

    // ── 清理：删频道及从属行（沙盒内自家夹具）──
    await _cleanup(int.parse(channelId));
    flowLog('[AT-CS2] 全部 PASS，夹具已清理');
  });
}
