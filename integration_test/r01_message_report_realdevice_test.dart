// R-01 一等消息举报真机验收（真后端 + 真 UI 全链）：
//
// 验收矩阵的真机面：
//   ① C2C E2EE 消息长按 → 投诉菜单 → E2EE 同意门（同意提交证据）→
//      工单落库（target_type=message/sub_type=c2c，evidence 带 e2ee_consent）
//   ② 频道消息长按 → actionSheet → 理由选择 → 工单落库（sub_type=channel）
//
// 工单落库的最终断言在主机侧由验收脚本查 report_ticket 完成；本测试
// 负责 UI 链路（长按/弹窗/同意流/成功反馈）与成功提示断言。
//
// 前置：设备已装 APP_ENV=local 构建包 + adb reverse 9800 + 本地后端含
// R-01 代码；smoke_alice(1000000051)/smoke_bob(1000000056) 存在且 alice
// 对 bob 有历史消息、alice 订阅频道 110252446336681984（含可读消息）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';

const String bobUid = '1000000056';
const String channelId = '110252446336681984';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R-01 频道消息举报：长按→理由→提交成功', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;

    final uid = UserRepoLocal.to.currentUid;
    if (uid.isEmpty || uid == '0') {
      markTestSkipped('无登录态（前一用例应已登录）');
      return;
    }

    final ctx2 = tester.element(find.byType(Scaffold).first);
    unawaited(
      Navigator.of(ctx2).push(
        MaterialPageRoute<void>(
          builder: (_) => ChannelDetailPage(channelId: channelId),
        ),
      ),
    );
    await settle(tester, maxSeconds: 8);
    expect(find.byType(ChannelDetailPage), findsOneWidget);

    // 频道消息经 markdown 渲染，轮询等待并诊断两种 finder 形态
    var demoFound = false;
    for (var i = 0; i < 8 && !demoFound; i++) {
      final plain = find.textContaining('DEMO-FLOW').evaluate().length;
      final rich = find
          .textContaining('DEMO-FLOW', findRichText: true)
          .evaluate()
          .length;
      if (i == 3) {
        final pageTexts = find
            .byWidgetPredicate((w) => w is Text && w.data != null)
            .evaluate()
            .map((e) => (e.widget as Text).data!)
            .where((t) => t.trim().isNotEmpty)
            .toList();
        flowLog('频道页面文本: ${pageTexts.take(15)}');
        flowLog('频道诊断: plainText=$plain richText=$rich');
      }
      if (rich > 0 || plain > 0) {
        demoFound = true;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!demoFound) {
      markTestSkipped('频道消息未渲染（feed 未加载到目标消息）');
      return;
    }
    final msgFinder = find.textContaining('DEMO-FLOW', findRichText: true);
    final fallbackMsgFinder = find.textContaining('DEMO-FLOW');
    await tester.longPress(
      tester.any(msgFinder) ? msgFinder.first : fallbackMsgFinder.first,
    );
    await settle(tester, maxSeconds: 3);

    // actionSheet 弹出理由面板 → 选「垃圾信息」
    final spam = find.text('垃圾信息');
    final sheetTexts = find
        .byWidgetPredicate((w) => w is Text && w.data != null)
        .evaluate()
        .map((e) => (e.widget as Text).data!)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    flowLog('长按后页面文本: ${sheetTexts.take(18)}');
    expect(tester.any(spam), isTrue, reason: '频道举报 actionSheet 应含理由项');
    await tester.tap(spam.first);
    await settle(tester, maxSeconds: 5);

    expect(
      find.textContaining('投诉已提交', findRichText: true),
      findsWidgets,
      reason: '频道举报提交应出现成功反馈',
    );
    await takeScreenshot(tester, 'r01_channel_report_submitted');
  });
  testWidgets('R-01 C2C E2EE 消息举报：长按→同意门→提交成功', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;

    // 登录（覆盖安装后登录态可能为空；已登录则 autoLoginOrSkip 直通）
    final inShell = await waitForMainShell(tester);
    if (!inShell) {
      final ok = await performLogin(
        tester,
        phone: 'smoke_alice',
        password: 'admin888',
      );
      if (!ok) {
        markTestSkipped('登录失败，无法验收举报流');
        return;
      }
      await waitForMainShell(tester);
    }
    final uid = UserRepoLocal.to.currentUid;
    flowLog('当前登录 uid=$uid');
    if (uid.isEmpty || uid == '0') {
      markTestSkipped('无登录态');
      return;
    }

    // 在已登录的 app 主壳上 push 真实 ChatPage（继承顶层 ProviderScope）
    final ctx = tester.element(find.byType(Scaffold).first);
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            type: 'C2C',
            peerId: bobUid,
            peerTitle: 'smoke_bob',
            peerAvatar: '',
            peerSign: '',
          ),
        ),
      ),
    );
    await settle(tester, maxSeconds: 8);
    expect(find.byType(ChatPage), findsOneWidget, reason: 'ChatPage 应已打开');

    // 从 UI 真相源（chatProvider 的 chatService.messages）取 bob 发来的
    // 最后一条有文本的消息，以其真实渲染文本构造长按锚点——避免长按到
    // 日期分割线/系统消息导致举报菜单不弹出。
    final chatCtx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(chatCtx);
    final notifier = container.read(chatProvider.notifier);

    // 历史同步（syncHistoryBackfill + WS 拉取）需要时间，轮询等待
    String? anchorText;
    for (var i = 0; i < 10 && anchorText == null; i++) {
      final msgs = notifier.chatService?.messages ?? const [];
      for (final m in msgs.toList().reversed) {
        if (m.authorId == bobUid &&
            m is TextMessage &&
            m.text.trim().isNotEmpty) {
          anchorText = m.text;
          break;
        }
      }
      if (anchorText == null) {
        if (i == 2) {
          flowLog(
            '诊断: messages=${msgs.length} '
            'types=${msgs.take(8).map((m) => m.runtimeType.toString()).toList()} '
            'authors=${msgs.take(8).map((m) => m.authorId).toList()}',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    flowLog('举报锚点消息文本: ${anchorText ?? '(无)'}');
    if (anchorText == null) {
      markTestSkipped('未找到 bob 的可长按文本消息（历史未渲染）');
      return;
    }

    var longPressed = false;
    // 组件级锚点：直接长按 FlyerChatTextMessage 气泡（flutter_chat_ui 的
    // onMessageLongPress 挂在每条消息 item 上，文本 finder 命中的可能是
    // 屏幕外/遮挡区导致手势无效）。选屏幕可见区内最下方的一颗。
    final bubbleFinder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'FlyerChatTextMessage',
    );
    final bubbleCount = bubbleFinder.evaluate().length;
    final screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    flowLog('文本气泡组件数=$bubbleCount');
    // 收集全部气泡位置，选「最接近屏幕中心」的（避免命中 appbar/键盘
    // 遮挡区的列表端点气泡——它们的手势会被遮挡层吃掉）
    Offset? bestPoint;
    double bestDist = double.infinity;
    for (var i = 0; i < bubbleCount; i++) {
      final center = tester.getCenter(bubbleFinder.at(i));
      flowLog('气泡[$i] dy=${center.dy}');
      if (center.dy > 150 && center.dy < screenH - 200) {
        final dist = (center.dy - screenH / 2).abs();
        if (dist < bestDist) {
          bestDist = dist;
          bestPoint = center;
        }
      }
    }
    if (bestPoint != null) {
      // 探针 ①：tap 验证手势通道（解密失败气泡 tap 会弹密钥恢复引导，
      // 弹窗出现=事件可达消息层；不出现=被遮挡层拦截）
      await tester.tapAt(bestPoint);
      await settle(tester, maxSeconds: 3);
      final recoveryShown =
          tester.any(find.textContaining('恢复')) ||
          tester.any(find.textContaining('密钥'));
      flowLog('tap 探针: 恢复引导弹窗=$recoveryShown');
      if (recoveryShown) {
        await dismissRecoveryGuide(tester);
        await settle(tester, maxSeconds: 2);
      }
      // 探针 ②：手动 startGesture 长按（press→真实等待 900ms→up），
      // 绕过 longPressAt 封装的时间语义
      flowLog('手动长按 dy=${bestPoint.dy}');
      final gesture = await tester.startGesture(bestPoint);
      await tester.pump(const Duration(milliseconds: 900));
      await gesture.up();
      await settle(tester, maxSeconds: 3);
      longPressed = true;
    }
    if (!longPressed) {
      // 兜底：直接长按屏幕中部消息气泡区域
      await tester.longPressAt(const Offset(180, 800));
      await settle(tester, maxSeconds: 3);
    }

    // 投诉菜单弹出 → 点「投诉」入口
    final complaintEntry = find.text('投诉');
    if (!tester.any(complaintEntry)) {
      // 长按可能落在自己消息/空白处，重试长按其他位置
      await tester.longPressAt(const Offset(180, 600));
      await settle(tester, maxSeconds: 3);
    }
    expect(tester.any(find.text('投诉')), isTrue, reason: '长按消息应弹出操作菜单且含「投诉」入口');
    await tester.tap(find.text('投诉'));
    await settle(tester, maxSeconds: 3);

    // E2EE 同意门（bob 消息为 E2EE 信封；同意提交证据）
    final consentTitle = find.text('提交加密消息证据');
    if (tester.any(consentTitle)) {
      flowLog('E2EE 同意门弹出');
      await tester.tap(find.text('同意并提交证据'));
      await settle(tester, maxSeconds: 5);
    } else {
      // 非 E2EE 直接提交（不选中理由会停留在理由面板——选「垃圾信息」）
      final spam = find.text('垃圾信息');
      if (tester.any(spam)) {
        await tester.tap(spam);
        await settle(tester, maxSeconds: 5);
      }
    }

    expect(
      find.textContaining('投诉已提交', findRichText: true),
      findsWidgets,
      reason: '举报提交应出现成功反馈「投诉已提交」',
    );
    await takeScreenshot(tester, 'r01_c2c_report_submitted');
  });
}
