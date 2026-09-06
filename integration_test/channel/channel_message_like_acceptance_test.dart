// integration_test/channel/channel_message_like_acceptance_test.dart
//
// 频道消息点赞验收（批次117）：后端触发器 42846 修复的端到端回归。
// 缺陷背景：
//   - 触发器 fn_update_channel_message_reaction_summary 在 00000084 把空对象
//     兜底改为 '{}'::jsonb 后，聚合仍用返回 json 类型的聚合函数，
//     COALESCE(json, jsonb) 无公共类型 → 首次点赞即 42846 回滚（UI 报"点赞失败"）；
//     00000089 迁移统一为 jsonb_object_agg（imboy 仓）。
//   - GET /reaction 曾被 add_reaction 吞掉（读一次=点赞一次），已按 method 分派修复。
// 覆盖：
//   AT-CL1 点赞：UI 乐观计数 + 服务端 channel_reaction 落行 + reaction 列表接口可见
//   AT-CL2 取消点赞：计数回落 + 列表接口回空
// 数据前置（本地 PG 4323 / 后端 9801，无第三方打扰）：
//   - 频道 110252446336681984（DEMO-FLOW）含消息 110252446493968384
//     （内容前缀 DEMO-FLOW-20260827）
//   - 重跑前清残留（保持"未点赞"初态）：
//     DELETE FROM channel_reaction WHERE message_id=110252446493968384 AND user_id=1000000056;
//     UPDATE channel_message SET reaction_summary='{}'::jsonb WHERE id=110252446493968384;
//
// 运行配方同 channel_subscriber_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/material.dart' show Navigator;
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _channelId = '110252446336681984';
const _messageId = '110252446493968384';
const _contentPrefix = 'DEMO-FLOW-20260827';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

/// 服务端 reaction 列表（回归 GET /reaction 的 method 分派修复）中的 like 计数。
Future<int> _serverLikeCount(FlowApiClient client) async {
  final resp = await client.get(
    '/api/v1/channel/$_channelId/message/$_messageId/reaction',
  );
  if (resp['code'] != 0) {
    fail('reaction 列表接口应成功: ${resp['msg']}');
  }
  final payload = resp['payload'];
  if (payload is! Map) return 0;
  final list = payload['list'];
  if (list is! List) return 0;
  for (final row in list) {
    if (row is Map && '${row['reaction_type']}' == 'like') {
      final cnt = row['cnt'];
      if (cnt is num) return cnt.toInt();
      return int.tryParse('$cnt') ?? 0;
    }
  }
  return 0;
}

/// 轮询等服务端 like 计数达期望值（写接口与触发器聚合均为同步事务，
/// 此处只吸收 HTTP 往返抖动）。
Future<int> _pollLikeCount(
  WidgetTester tester,
  FlowApiClient client,
  int expected,
) async {
  var cnt = -1;
  for (var i = 0; i < 10; i++) {
    cnt = await _serverLikeCount(client);
    if (cnt == expected) break;
    await _pump(tester, seconds: 1);
  }
  return cnt;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-CL 频道消息点赞 2 行', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    final baseUrl = FlowApiConfig.apiBaseUrl;
    if (baseUrl.isEmpty) {
      fail('需要 API_BASE_URL dart-define 指向本地后端');
    }
    app.main();
    await _pump(tester, seconds: 12);
    if (!await checkPreconditions(tester)) return;
    final loggedIn = await autoLoginOrSkip(tester);
    if (!loggedIn) return;
    expect(
      UserRepoLocal.to.currentUid,
      _expectedUid,
      reason: '必须是 smoke_bob（该频道订阅者）',
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await _pump(tester, seconds: 2);

    // API 断言客户端：复用 App 主会话 token（独立 login 会触发「另一设备登录」
    // 把 App 挤下线，run2 已实证），did 仅参与签名头，不复用 App 值。
    final client = FlowApiClient(baseUrl: baseUrl, deviceId: 'channel-like');
    client.accessToken = await UserRepoLocal.to.accessToken;

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push('/channel/$_channelId');
    await _pump(tester, seconds: 5);

    // ---- 前置：消息流渲染 + 初态确认 ----
    final msgShown = await _waitFor(
      tester,
      () => tester.any(find.textContaining(_contentPrefix)),
      seconds: 15,
    );
    expect(msgShown, isTrue, reason: '频道详情页应渲染目标消息');
    final likeLabel = find.text('点赞');
    expect(tester.any(likeLabel), isTrue, reason: '初态点赞按钮 label 应为「点赞」');
    expect(
      await _pollLikeCount(tester, client, 0),
      0,
      reason: '前置：服务端应无 like 反应',
    );

    // ---- AT-CL1 点赞 ----
    await tester.tap(likeLabel.first, warnIfMissed: false);
    final liked1 = await _waitFor(
      tester,
      () => tester.any(find.text('1')),
      seconds: 10,
    );
    expect(liked1, isTrue, reason: 'AT-CL1 点赞后 UI 计数应变为 1');
    expect(
      tester.any(find.textContaining('操作失败')),
      isFalse,
      reason: 'AT-CL1 点赞不应出现失败提示',
    );
    final likeCnt = await _pollLikeCount(tester, client, 1);
    expect(likeCnt, 1, reason: 'AT-CL1 服务端 channel_reaction 应有 1 条 like');
    flowLog('[AT-CL1] 点赞：UI 计数 0→1，服务端 like=$likeCnt');

    // ---- AT-CL2 取消点赞（按钮 label 此时为 '1'）----
    await tester.tap(find.text('1').first, warnIfMissed: false);
    final unliked = await _waitFor(
      tester,
      () => tester.any(find.text('点赞')),
      seconds: 10,
    );
    expect(unliked, isTrue, reason: 'AT-CL2 取消后按钮应回落为「点赞」');
    expect(
      tester.any(find.textContaining('操作失败')),
      isFalse,
      reason: 'AT-CL2 取消不应出现失败提示',
    );
    final likeCnt2 = await _pollLikeCount(tester, client, 0);
    expect(likeCnt2, 0, reason: 'AT-CL2 服务端 like 反应应被移除');
    flowLog('[AT-CL2] 取消点赞：UI 计数回落，服务端 like=$likeCnt2');

    client.close();
  });
}
