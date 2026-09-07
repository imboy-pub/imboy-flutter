// integration_test/channel/paid_channel_acceptance_test.dart
//
// Channel 付费域验收（批次122）：解锁 channel 付费 20 行阻塞
// （paywall 锁定 1 + 订单列表 9 + 订单详情 10 中的本地可构造行）。
// 载体：买家 SmokeEmpty（account=51730）；频道 owner=smoke_bob(1000000056)。
// 资金红线：仅本地 mock 环境（9801/4323），钱包余额为 mock 资金；
//          对生产地址一律 SKIP。
//
// 前置（bash 编排，见 /tmp/paid_batch.sh）：
//   1. imboy/scripts/paid_channel_fixture.sh create
//      （PAID_FIXTURE_OWNER_UID=1000000056 BUYER_UID=<SmokeEmpty>，双确认 env）
//      → 输出 TEST_PAID_CHANNEL_ID
//   2. curl login(51730) + POST /api/v1/wallet/topup {amount:2000}
//      （钱包余额走后端真实建行，amount 为分）
//
// 场景（顺序依赖：CP2 空态需先删单；CP4~CP6、CP8 依赖 CP3 的订单）：
//   AT-CP1 付费频道 paywall 锁定视图（标题/提示/价格/购买/我的订单）
//   AT-CP2 订单列表空态（前置 SQL 删单，可重复回归）
//   AT-CP3 购买链：购买按钮 → 支付方式 sheet 钱包余额 → 购买成功 toast
//          → paywall 消失 + fixture 内容消息出现（购买后刷新）
//   AT-CP4 订单列表渲染：频道名 / ¥9.90 两位小数 / 已支付状态标签
//   AT-CP5 点击订单项跳转订单详情页
//   AT-CP6 订单详情字段：订单号/频道/金额/状态/支付方式=钱包余额/
//          下单时间/支付时间/订阅周期
//   AT-CP7 订单不存在（假单号深链）兜底视图
//   AT-CP8 退款链：申请退款 → 确认弹窗 → 退款申请已提交 → 已退款状态
//
// 运行（单场景 --plain-name；define 与批次121 相同配方 + TEST_PAID_CHANNEL_ID）：
//   flutter test integration_test/channel/paid_channel_acceptance_test.dart \
//     -d macos --plain-name "AT-CP1" \
//     --dart-define=APP_ENV=local_office \
//     ... 同批次121 ... \
//     --dart-define=TEST_PAID_CHANNEL_ID=<fixture 输出> \
//     --dart-define=TEST_ALLOW_PAID_CHANNEL_WRITES=true

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _channelId = String.fromEnvironment('TEST_PAID_CHANNEL_ID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_PAID_CHANNEL_WRITES',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

/// fixture 频道名（paid_channel_fixture.sh 写死）与内容消息正文
const _fixtureChannelName = 'IMBoy local paid fixture';
const _fixtureMessageBody = 'paid-channel-fixture-content';
const _fixturePriceText = '¥9.90';

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

/// 启动 + 登录（批次120/121 同款防御：启动期旧 token 401 风暴会迟到踢
/// 会话，失败整体重试）。SmokeEmpty 零工作区，登录稳定后落点为
/// workspace bootstrap 引导页——频道域路由独立于 shell，直接深链。
Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  for (var i = 0; i < 10; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区'))) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区'))) {
    markTestSkipped('未到达登录稳定态（workspace 引导页）');
    return false;
  }
  expect(
    UserRepoLocal.to.currentUid,
    _expectedUid,
    reason: '必须是 SmokeEmpty（付费域买家载体）',
  );
  return true;
}

void _go(WidgetTester tester, String path) {
  GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
}

/// 当前买家在 fixture 频道的最新订单号（CP4 之后的订单场景依赖）。
Future<String?> _latestOrderNo() async {
  return await TestPg.scalar(
        'SELECT order_no FROM channel_order '
        'WHERE user_id = @uid AND channel_id = @cid '
        'ORDER BY created_at DESC LIMIT 1',
        {'uid': int.parse(_expectedUid), 'cid': int.parse(_channelId)},
      )
      as String?;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-CP1 付费频道 paywall 锁定视图', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    _go(tester, '/channel/$_channelId');
    final paywall = await _waitFor(
      tester,
      () => tester.any(find.text('付费频道内容已锁定')),
      seconds: 20,
    );
    expect(paywall, isTrue, reason: '付费未购买频道应渲染 paywall 锁定视图');
    expect(
      tester.any(find.text('购买后可解锁频道历史消息与后续更新内容。')),
      isTrue,
      reason: '应渲染解锁提示副标题',
    );
    expect(
      tester.any(find.textContaining('9.90')),
      isTrue,
      reason: '应渲染 fixture 价格（channel_price.price=9.90）',
    );
    expect(tester.any(find.text('立即购买并解锁')), isTrue, reason: '应渲染购买按钮');
    expect(tester.any(find.text('我的订单')), isTrue, reason: '应渲染我的订单入口');
  });

  testWidgets('AT-CP2 订单列表空态（前置删单，可重复回归）', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    // 本地测试库、买家自己的测试订单：删除以恢复「无订单」空态（可重跑）
    await TestPg.execute('DELETE FROM channel_order WHERE user_id = @uid', {
      'uid': int.parse(_expectedUid),
    });

    _go(tester, '/channel/orders');
    final empty = await _waitFor(
      tester,
      () => tester.any(find.text('暂无订单记录')),
      seconds: 15,
    );
    expect(empty, isTrue, reason: '无订单时应渲染列表空态');
    expect(
      tester.any(find.text(_fixtureChannelName)),
      isFalse,
      reason: '空态下不应有任何订单项',
    );
  });

  testWidgets('AT-CP3 购买链（钱包）+ 购买后刷新解锁', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    _go(tester, '/channel/$_channelId');
    final paywall = await _waitFor(
      tester,
      () => tester.any(find.text('立即购买并解锁')),
      seconds: 20,
    );
    expect(paywall, isTrue, reason: '前置：paywall 与购买按钮可见');

    // 800x600 测试视口下购买按钮（y≈725）在屏外：先滚动可见再点
    await tester.ensureVisible(find.text('立即购买并解锁'));
    await _pump(tester, seconds: 1);
    await tester.tap(find.text('立即购买并解锁'), warnIfMissed: false);
    await _pump(tester, seconds: 2);
    expect(tester.any(find.text('选择支付方式')), isTrue, reason: '应弹出支付方式选择 sheet');

    // 钱包项文本=「钱包余额  ¥xx.xx」（余额非空时拼接），用 textContaining
    await tester.tap(find.textContaining('钱包余额'));
    // toast 仅 3 秒存活：短 pump 内断言（批次120 教训）
    await _pump(tester, seconds: 1);
    expect(tester.any(find.text('购买成功')), isTrue, reason: '钱包支付成功应弹购买成功 toast');

    // 购买后刷新：paywall 消失，消息流出现 fixture 内容消息
    final unlocked = await _waitFor(
      tester,
      () =>
          !tester.any(find.text('付费频道内容已锁定')) &&
          tester.any(find.textContaining(_fixtureMessageBody)),
      seconds: 30,
    );
    expect(unlocked, isTrue, reason: '购买后应解锁消息流并渲染 fixture 内容消息');
  });

  testWidgets('AT-CP4 订单列表渲染（频道名/金额/状态标签）', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    final orderNo = await _latestOrderNo();
    expect(orderNo, isNotNull, reason: '前置：CP3 已产生订单（先跑 AT-CP3）');
    // 本地测试库：CP8 退款链会把订单翻成已退款，重跑 CP4 前重置为已支付
    await TestPg.execute(
      'UPDATE channel_order SET status = 1, refund_at = NULL, '
      'refund_reason = NULL WHERE user_id = @uid AND channel_id = @cid',
      {'uid': int.parse(_expectedUid), 'cid': int.parse(_channelId)},
    );

    _go(tester, '/channel/orders');
    final tile = await _waitFor(
      tester,
      () => tester.any(find.text(_fixtureChannelName)),
      seconds: 15,
    );
    expect(tile, isTrue, reason: '订单项应渲染 fixture 频道名');
    expect(
      tester.any(find.text(_fixturePriceText)),
      isTrue,
      reason: '金额应渲染 ¥+两位小数（9.90）',
    );
    expect(tester.any(find.text('已支付')), isTrue, reason: '已支付订单应渲染已支付状态标签');

    // 副标题=下单日期（YYYY-MM-DD）；type=1 无有效期后缀
    final today = DateTime.now().toString().split(' ').first;
    expect(
      tester.any(find.textContaining(today)),
      isTrue,
      reason: '订单项副标题应展示下单日期（$today）',
    );

    // 下拉刷新：RefreshIndicator 响应 drag → invalidate 重拉 → 列表仍渲染
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 150));
    final reloaded = await _waitFor(
      tester,
      () => tester.any(find.text(_fixtureChannelName)),
      seconds: 15,
    );
    expect(reloaded, isTrue, reason: '下拉刷新重拉后订单列表应正常渲染');
  });

  testWidgets('AT-CP5 点击订单项跳转订单详情页', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    final orderNo = await _latestOrderNo();
    expect(orderNo, isNotNull, reason: '前置：订单存在（先跑 AT-CP3）');
    // 本地测试库：CP8 退款链会把订单翻成已退款，重跑前重置为已支付
    await TestPg.execute(
      'UPDATE channel_order SET status = 1, refund_at = NULL, '
      'refund_reason = NULL WHERE user_id = @uid AND channel_id = @cid',
      {'uid': int.parse(_expectedUid), 'cid': int.parse(_channelId)},
    );

    _go(tester, '/channel/orders');
    final tile = await _waitFor(
      tester,
      () => tester.any(find.text(_fixtureChannelName)),
      seconds: 15,
    );
    expect(tile, isTrue, reason: '前置：订单项可见');
    await tester.tap(find.text(_fixtureChannelName).first);
    final detail = await _waitFor(
      tester,
      () => tester.any(find.text('订单号')),
      seconds: 15,
    );
    expect(detail, isTrue, reason: '点击订单项应跳转订单详情页');
    expect(
      tester.any(find.textContaining(orderNo!)),
      isTrue,
      reason: '详情应展示该订单号（$orderNo）',
    );
  });

  testWidgets('AT-CP6 订单详情字段行（支付方式映射/时间/订阅周期）', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    final orderNo = await _latestOrderNo();
    expect(orderNo, isNotNull, reason: '前置：订单存在（先跑 AT-CP3）');
    // 本地测试库：CP8 退款链会把订单翻成已退款，重跑前重置为已支付
    await TestPg.execute(
      'UPDATE channel_order SET status = 1, refund_at = NULL, '
      'refund_reason = NULL WHERE user_id = @uid AND channel_id = @cid',
      {'uid': int.parse(_expectedUid), 'cid': int.parse(_channelId)},
    );
    _go(tester, '/channel/order/$orderNo');

    final loaded = await _waitFor(
      tester,
      () => tester.any(find.text('订单号')),
      seconds: 15,
    );
    expect(loaded, isTrue, reason: '按订单号深链应加载详情');
    expect(tester.any(find.text('订单详情')), isTrue, reason: 'AppBar 标题');
    expect(tester.any(find.textContaining(orderNo!)), isTrue, reason: '订单号字段行');
    expect(
      tester.any(find.text(_fixtureChannelName)),
      isTrue,
      reason: '频道字段行应渲染频道名',
    );
    expect(tester.any(find.text(_fixturePriceText)), isTrue, reason: '金额字段行');
    expect(tester.any(find.text('已支付')), isTrue, reason: '状态标签行');
    expect(
      tester.any(find.text('钱包余额')),
      isTrue,
      reason: '支付方式 wallet 应映射为「钱包余额」',
    );
    expect(tester.any(find.text('下单时间')), isTrue, reason: '下单时间字段行');
    expect(tester.any(find.text('支付时间')), isTrue, reason: '已支付订单应展示支付时间');
    // fixture 为 subscription_type=1（一次性购买）：后端 subscription_end/1
    // 对 type=1 返回 null，按设计不渲染订阅周期行；周期行属 type=2/3 订阅型。
    expect(
      tester.any(find.text('订阅周期')),
      isFalse,
      reason: '一次性购买（type=1）不渲染订阅周期行',
    );
    expect(tester.any(find.text('申请退款')), isTrue, reason: '已支付订单展示退款入口');
  });

  testWidgets('AT-CP7 订单不存在（假单号深链）兜底视图', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    _go(tester, '/channel/order/CP7-NO-SUCH-ORDER');
    final fallback = await _waitFor(
      tester,
      () => tester.any(find.text('暂无订单记录')),
      seconds: 15,
    );
    expect(fallback, isTrue, reason: '假单号应渲染兜底视图（不崩溃）');
    // ignore: avoid_print
    print(
      'DIAG CP7: 假单号落点文本=${tester.widgetList(find.bySubtype<Text>()).whereType<Text>().map((w) => w.data).whereType<String>().toSet().take(12).join(" | ")}',
    );
  });

  testWidgets('AT-CP8 退款链（申请→确认→已退款）', (tester) async {
    if (!_allow || _channelId.isEmpty) {
      markTestSkipped(
        '需 TEST_ALLOW_PAID_CHANNEL_WRITES=true + TEST_PAID_CHANNEL_ID',
      );
      return;
    }
    if (!await _boot(tester)) return;

    final orderNo = await _latestOrderNo();
    expect(orderNo, isNotNull, reason: '前置：订单存在（先跑 AT-CP3）');
    // 本地测试库：CP8 退款链会把订单翻成已退款，重跑前重置为已支付
    await TestPg.execute(
      'UPDATE channel_order SET status = 1, refund_at = NULL, '
      'refund_reason = NULL WHERE user_id = @uid AND channel_id = @cid',
      {'uid': int.parse(_expectedUid), 'cid': int.parse(_channelId)},
    );
    _go(tester, '/channel/order/$orderNo');
    final loaded = await _waitFor(
      tester,
      () => tester.any(find.text('申请退款')),
      seconds: 15,
    );
    expect(loaded, isTrue, reason: '前置：已支付订单详情含退款入口');

    // 退款按钮在长 ListView 尾部，可能滚出 800x600 视口：先滚动可见再点
    await tester.ensureVisible(find.text('申请退款'));
    await _pump(tester, seconds: 1);
    await tester.tap(find.text('申请退款'), warnIfMissed: false);
    await _pump(tester, seconds: 2);
    expect(tester.any(find.text('确认退款')), isTrue, reason: '应弹出退款确认弹窗');
    expect(
      tester.any(find.text('确定要对该订单申请退款吗？退款后将取消订阅。')),
      isTrue,
      reason: '确认弹窗应提示退款后果',
    );

    await tester.tap(find.text('确认'));
    await _pump(tester, seconds: 1);
    expect(tester.any(find.text('退款申请已提交')), isTrue, reason: '退款受理成功应弹 toast');

    final refunded = await _waitFor(
      tester,
      () => tester.any(find.text('已退款')),
      seconds: 20,
    );
    expect(refunded, isTrue, reason: '退款后状态标签应变为已退款');
    expect(tester.any(find.text('申请退款')), isFalse, reason: '已退款订单不再展示退款入口');
  });
}
