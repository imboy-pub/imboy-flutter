// integration_test/helpers/chat_multi_driver.dart
//
// W3-K 多选消息真机旅程驱动层（RUN_ID=chat-multi-20261111）。
//
// 与 chat_multi_fixtures.dart 的分工：
// - fixtures 是**纯 Dart**（无 flutter_test/integration_test 依赖），
//   与 test/unit_test/page/chat/integration_smoke/ 本地冒烟共享；
// - 本文件只服务 integration_test/（依赖 flows/test_utils 与真实页面）。
//
// 驱动策略：全部经稳定 Key / Semantics / 既有 journey 支撑位（长按菜单、
// SendToPage）操作真实 UI，不注入任何假数据到生产 provider。

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

import '../flows/test_utils.dart';
import 'chat_multi_fixtures.dart';

/// 长按菜单「多选」入口定位器（w2-e：入口文案来自 t.chat.multiSelect，
/// 图标固定 CupertinoIcons.checkmark_circle；icon 兜底不依赖 locale）。
List<Finder> chatMultiMenuEntryFinders() {
  return <Finder>[
    find.byIcon(CupertinoIcons.checkmark_circle),
    find.text('多选'),
    find.text('Select'),
    find.text('Mehrfachauswahl'),
    find.text('選択'),
    find.text('选择'),
    find.text('Множественный выбор'),
    find.text('Sélection multiple'),
    find.text('Selección múltiple'),
    find.text('Selezione multipla'),
    find.text('다중 선택'),
    find.text('تحديد متعدد'),
  ];
}

/// 依据 runtimeType 判定 SendToPage 是否在树（flows 同款判定法；
/// send_to_page.dart 未暴露稳定 Key）。
bool isOnSendToPage(WidgetTester t) {
  return t.any(
    find.byWidgetPredicate((w) => w.runtimeType.toString() == 'SendToPage'),
  );
}

/// 开启三个 rollout flag（chat_multi_select_v1 等），返回 override；
/// 调用方负责在用例末尾 `override.restore()`。
ChatMultiFlagOverride enableChatMultiFlagsForTest({
  bool multiSelect = true,
  bool bundle = true,
  bool export = true,
}) {
  return ChatMultiFlagOverride()
    ..enableAll(multiSelect: multiSelect, bundle: bundle, export: export);
}

/// 直接 push 真实 ChatPage（与 c2c_e2ee_send_render_test 同款入口，
/// 绕过会话列表对存量会话的依赖 —— 首条消息发送后即建立会话行）。
Future<Finder> pushChatPage(
  WidgetTester tester, {
  required String type,
  required String peerId,
  required String peerTitle,
}) async {
  final ctx = tester.element(find.byType(Scaffold).first);
  unawaited(
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          type: type,
          peerId: peerId,
          peerTitle: peerTitle,
          peerAvatar: '',
          peerSign: '',
        ),
      ),
    ),
  );
  await settle(tester, maxSeconds: 6);
  final chatPage = find.byType(ChatPage);
  expect(chatPage, findsOneWidget, reason: 'ChatPage 应已 push 打开');
  return chatPage;
}

/// 关闭当前 ChatPage（pop 一层路由）。
Future<void> popTopPage(WidgetTester tester, Finder chatPage) async {
  final ctx = tester.element(chatPage.first);
  Navigator.of(ctx).pop();
  await settle(tester, maxSeconds: 3);
}

/// 含 [marker] 文本的消息条目（ChatMessageItem；仅文本类消息可读 text）。
Finder chatMultiItemContaining(String marker) => find.byWidgetPredicate(
  (w) => w is ChatMessageItem && _textOf(w.message).contains(marker),
);

String _textOf(core.Message m) {
  final text = m is core.TextMessage ? m.text : '';
  return text;
}

/// 读取含 [marker] 消息条目的消息对象（含 id/createdAt/status）。
core.Message? messageOfMarker(WidgetTester tester, String marker) {
  final f = chatMultiItemContaining(marker);
  if (!tester.any(f)) return null;
  return tester.widget<ChatMessageItem>(f.first).message;
}

/// 经长按菜单进入多选：长按 [bubble] → 菜单点「多选」→ action bar 出现。
///
/// ⚠️ W1-A enter 契约（chat_page._enterMultiSelect → MessageSelectionNotifier
/// .enter）：长按菜单「多选」会**进入多选并选中被长按的消息** —— 返回后
/// action bar 计数恒为 1（[bubble] 对应消息已在选中集）。调用方不要再对该
/// 消息 toggle（会把它勾掉，DEV-01 pass1/pass2 双轮失败的确定性根因之一）；
/// 本函数尾部对计数=1 做契约断言，防止用例层再犯。
Future<void> enterMultiSelectViaMenu(
  WidgetTester tester,
  Finder bubble, {
  String journey = 'W3K',
}) async {
  expect(tester.any(bubble), isTrue, reason: '$journey 长按目标气泡应在列表');
  await tester.longPress(bubble.first);
  await settle(tester, maxSeconds: 2);
  final entered = await tapAny(tester, chatMultiMenuEntryFinders());
  if (!entered) {
    await takeScreenshot(tester, 'w3k_diag_menu_without_multiselect');
    fail('$journey 长按菜单未见「多选」入口 —— flag 未开启或消息不可选');
  }
  await settle(tester, maxSeconds: 2);
  expect(
    tester.any(find.byKey(ChatMultiKeys.cancel)),
    isTrue,
    reason: '$journey 进入多选后 action bar（multi_select_cancel）应出现',
  );
  expectSelectionCount(tester, 1);
  await flushPendingPointerPacket(tester);
}

/// 冲刷进入多选转场后引擎侧挂起的 pointer packet（真机 live binding 特有）。
///
/// DEV-01 probe1-3 证据：进入多选（leading 头像↔勾选框、输入区↔action bar
/// 双重布局切换）后，首个注入 tap 间歇性在引擎 packet 边界被延迟/丢弃 ——
/// probe1/probe2 入场后首个 tap 不注册（计数不变），probe3 迟到的 packet 与
/// 下一次 tap 一并生效（一次勾了两条）。生产侧勾选 GestureDetector 无缺陷
/// （命中即正确切换，probe2 traits 全 selectable=true），修复在 driver 层：
/// 以 action bar 计数文本（无任何手势处理器，tap 零副作用）作牺牲 tap 吸收
/// 首个挂起 packet；随后真延时 > kDoubleTapTimeout（300ms）排帧，保证后续
/// 勾选 tap 全部落在稳定的手势管线上。
Future<void> flushPendingPointerPacket(WidgetTester tester) async {
  final warm = find.byKey(ChatMultiKeys.count);
  if (tester.any(warm)) {
    await tapViaNewGesture(tester, warm);
  }
  await pacedWait(tester, 350);
  await settle(tester, maxSeconds: 1);
}

/// 双时钟安全等待 [ms] 毫秒：真机 live binding 走真实时钟（Future.delayed
/// 生效）；本地 widget 冒烟走 fake binding —— pump 推进假时钟触发同一
/// timer。顺序必须「先建 timer → pump 推进 → await」，先 await 后 pump 会
/// 在 fake binding 死锁（pumpAndSettle 在无挂起帧时不推进假时钟）。
Future<void> pacedWait(WidgetTester tester, int ms) async {
  final waiter = Future<void>.delayed(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
  await waiter;
}

/// 唯一指针 tap：tester.tap 复用 pointer=0 —— 真机上被吞/迟到的 packet 会
/// 令 pointer 0 的 down/up 配对错乱，后续 tap 与悬挂的旧指针状态串线
/// （probe3 同坐标两次 tap 勾中两条不同消息、final-pass1 r2-v3 计数反向
/// 2→1 误中已选行的证据）。startGesture 为每次 tap 分配独立 pointer，
/// down/up 成对交付，杜绝跨 tap 指针串扰。
Future<void> tapViaNewGesture(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await gesture.up();
  await gesture.removePointer();
}

/// 在多选模式下勾选某条消息（driver 只用于「选上」语义，不用于取消）。
/// 优先点勾选框稳定 Key（44pt 触达区），兜底点气泡本体（tap-toggle）。
///
/// 真机（LiveTestWidgetsFlutterBinding）两类注入失败模式（DEV-01 probe1-3 +
/// fix-pass1-r2 / final-pass1 证据），生产勾选 GestureDetector 均无缺陷
/// （命中即正确切换）：
/// ① tap 被吞：入场布局切换（leading 头像↔勾选框、输入区↔action bar）后
///    首个 pointer packet 在引擎边界被延迟/丢弃 —— probe1/2 入场首 tap 不
///    注册、probe3 迟到 packet 与下一 tap 一并生效（一次勾两条）。对策：
///    enter 后 flushPendingPointerPacket 牺牲 tap + 重试间隔 pacedWait
///    ≥350ms（跨 kDoubleTapTimeout 与 packet 交付窗口）。
/// ② tap 误投：fixture 图像异步解码展开令整列位移 —— tap() 取坐标时行在
///    旧位、事件命中时行已移位（probe1 同坐标两次 tap 勾中两个不同行；
///    final-pass1 前缀截图 t3 被误勾、本次 r1 计数 2→1 误中已选行）。
///    对策：tap 前布局稳定性门（目标 rect ≥400ms 窗口两次取样一致才出手）；
///    tap 后语义校验（计数 +1 且目标框呈选中态）；误投自愈（撤销误勾行）。
/// 校验不通过即重试（重新解析 finder 取最新几何）；重试耗尽交调用方
/// expectSelectionCount 以实际计数失败 —— 不在 driver 层吞断言。
Future<void> toggleMessageSelection(
  WidgetTester tester,
  Finder bubble, {
  String? messageId,
  int maxAttempts = 3,
}) async {
  Finder targetOf() {
    final byKey = messageId != null
        ? find.byKey(chatMultiCheckboxKey(messageId))
        : null;
    if (byKey != null && tester.any(byKey)) return byKey;
    return bubble;
  }

  final before = actionBarSelectedCount(tester);
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (attempt > 1) {
      // 对策①重试节流：见函数头。重试是「独立 tap」，不与前一 tap 合并。
      await pacedWait(tester, 350);
    }
    // tap 前排帧：入场动画/弹层退出/图片加载循环挂起的帧先落定。
    await settle(tester, maxSeconds: 2);

    // 对策②布局稳定性门：目标 rect 在 ≥400ms 窗口内两次取样一致才 tap，
    // 杜绝「取坐标时行在旧位、命中时行已移位」。最多重取样 5 次（~1s），
    // 覆盖 fixture 图像解码展开的整列位移；仍不稳则带病 tap，交语义校验兜底。
    Rect? rectA;
    for (var i = 0; i < 5; i++) {
      rectA = tester.any(targetOf()) ? tester.getRect(targetOf().first) : null;
      await pacedWait(tester, 200);
      final rectB = tester.any(targetOf())
          ? tester.getRect(targetOf().first)
          : null;
      if (rectA != null && rectB != null && rectA == rectB) break;
      rectA = null;
      await settle(tester, maxSeconds: 1);
    }
    final target = targetOf();
    final tappedCheckbox =
        messageId != null &&
        tester.any(find.byKey(chatMultiCheckboxKey(messageId)));
    await tapViaNewGesture(tester, target);
    await settle(tester, maxSeconds: 2);
    final after = actionBarSelectedCount(tester);
    final bool verified;
    if (before != null && after != null) {
      final delta = after - before;
      if (delta == 1 && tappedCheckbox) {
        // 语义校验：必须是「目标行被勾上」—— 目标勾选框呈选中态（实心圈）。
        verified = tester.any(
          find.descendant(
            of: target,
            matching: find.byIcon(CupertinoIcons.checkmark_circle_fill),
          ),
        );
      } else {
        // delta==1 且兜底路径（气泡 tap，无勾选框可验）：计数 +1 即认。
        // delta<=0：tap 被吞或误中已选行（r1 证据 2→1）；delta>=2：一次
        // 勾了两条（probe3 迟到 packet 合并）—— 均视为未注册，重试。
        verified = delta == 1;
      }
    } else if (before == null && after == null) {
      // 多选栏不可校验（兜底路径）：交由调用方 expectSelectionCount 判定。
      verified = true;
    } else {
      // 计数文本状态异常（多选栏被误关等）→ 视为未注册，重试。
      verified = false;
    }
    if (verified) return;
    flowLog(
      'W3K 勾选 tap 未注册/误投（尝试 $attempt/$maxAttempts）: '
      '计数 $before → $after tappedCheckbox=$tappedCheckbox',
    );
    if (before != null && after != null && after > before) {
      // 对策②误投自愈：有非目标行被误勾（计数涨了但目标没亮）。撤销全部
      // 误勾行，再进入下一次重试 —— 防误勾污染后续累计断言。
      await undoWrongSelections(tester, messageId);
    }
  }
}

/// 撤销误勾：勾掉所有非 [messageId] 的已勾选行（勾选框呈实心圈图标，
/// 且 Key 属 multi_select_check_ 族的行）。messageId 为 null 时不动
/// （无法判定目标族，交调用方断言兜底）。
Future<void> undoWrongSelections(WidgetTester tester, String? messageId) async {
  if (messageId == null) return;
  final boxes = find
      .byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('multi_select_check_'),
      )
      .evaluate()
      .toList();
  for (final el in boxes) {
    final key = (el.widget as GestureDetector).key as ValueKey<String>;
    if (key.value == 'multi_select_check_$messageId') continue;
    final checked = tester.any(
      find.descendant(
        of: find.byKey(key),
        matching: find.byIcon(CupertinoIcons.checkmark_circle_fill),
      ),
    );
    if (!checked) continue;
    flowLog('W3K 撤销误勾: ${key.value}');
    await tapViaNewGesture(tester, find.byKey(key));
    await settle(tester, maxSeconds: 1);
  }
}

/// 解析 action bar 已选计数（t.chat.multiSelectCount 渲染值里的首个整数）。
/// 多选栏不在树 / 文本不可解析时返回 null。
int? actionBarSelectedCount(WidgetTester tester) {
  final raw = actionBarCountText(tester);
  final m = RegExp(r'\d+').firstMatch(raw);
  return m == null ? null : int.parse(m.group(0)!);
}

/// 读取 action bar 的已选计数原文（t.chat.multiSelectCount 渲染值）。
String actionBarCountText(WidgetTester tester) {
  final f = find.byKey(ChatMultiKeys.count);
  if (!tester.any(f)) return '<no-action-bar>';
  final widget = tester.widget<Text>(f.first);
  return widget.data ?? '<rich>';
}

/// 断言已选计数恰为 [expected]。
void expectSelectionCount(WidgetTester tester, int expected) {
  final raw = actionBarCountText(tester);
  expect(
    RegExp('(^|[^0-9])$expected([^0-9]|\$)').hasMatch(raw),
    isTrue,
    reason: 'action bar 计数应恰为 $expected（实际「$raw」）',
  );
}

/// 点 action bar 的某个动作键。
Future<void> tapActionBar(WidgetTester tester, Key key) async {
  final f = find.byKey(key);
  expect(tester.any(f), isTrue, reason: 'action bar 动作 $key 应在树上');
  await tester.tap(f.first, warnIfMissed: false);
  await settle(tester, maxSeconds: 2);
}

/// 从本地会话库解析目标会话的展示名（SendToNotifier.search 按 displayTitle
/// 过滤，C2C 行 title=对端昵称；群会话缺名时本兜底链失效，须传显式标题）。
Future<String> resolveTargetTitle({
  required String type,
  required String peerId,
  String fallback = '',
}) async {
  final conversation = await ConversationRepo().findByPeerId(type, peerId);
  final title = conversation?.displayTitle ?? '';
  if (title.isNotEmpty && title != peerId) return title;
  if (fallback.isNotEmpty) return fallback;
  return title;
}

/// 在 SendToPage 里搜索并选中目标会话，然后点「发送」。
///
/// 目标行按 [targetDisplayTitle] 匹配（SendToNotifier.search 只按
/// displayTitle 过滤；标题先用 [resolveTargetTitle] 从本地库解析）。
Future<void> selectForwardTargetAndSend(
  WidgetTester tester, {
  required String targetDisplayTitle,
  String journey = 'W3K',
  int maxSeconds = 20,
}) async {
  for (var i = 0; i < maxSeconds && isOnSendToPage(tester); i++) {
    if (tester.any(find.byType(CupertinoTextField))) break;
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(isOnSendToPage(tester), isTrue, reason: '$journey 目标页应已打开');

  final searchField = find.byType(CupertinoTextField).first;
  await tester.enterText(searchField, targetDisplayTitle);
  await settle(tester, maxSeconds: 2);

  final row = find.textContaining(targetDisplayTitle, findRichText: true);
  if (!tester.any(row)) {
    await takeScreenshot(tester, 'w3k_diag_target_not_listed');
    fail('$journey 目标页搜索结果无「$targetDisplayTitle」');
  }
  await tester.tap(row.first, warnIfMissed: false);
  await settle(tester, maxSeconds: 1);

  final sent = await tapAny(tester, [
    find.widgetWithText(CupertinoButton, '发送'),
    find.widgetWithText(CupertinoButton, 'Send'),
    find.widgetWithText(CupertinoButton, 'Senden'),
    find.text('发送'),
    find.text('Send'),
  ]);
  expect(sent, isTrue, reason: '$journey 未找到目标页发送按钮');
}

/// 批量转发完成后等待目标页关闭（全成功 → toast + 自动 pop）。
Future<void> waitBatchForwardSettled(
  WidgetTester tester, {
  String journey = 'W3K',
  int maxSeconds = 40,
}) async {
  for (var i = 0; i < maxSeconds && isOnSendToPage(tester); i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  if (isOnSendToPage(tester)) {
    await takeScreenshot(tester, 'w3k_diag_batch_not_settled');
    fail('$journey 批量转发 $maxSeconds 秒后目标页仍未关闭（存在失败单元？）');
  }
  await settle(tester, maxSeconds: 2);
}

/// 等待 [finder] 出现（真实时钟轮询，配合 integration_test 帧泵）。
Future<bool> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  int maxSeconds = 10,
  String screenshotName = 'w3k_wait_timeout',
}) async {
  for (var i = 0; i < maxSeconds * 2; i++) {
    if (tester.any(finder)) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  await takeScreenshot(tester, screenshotName);
  return tester.any(finder);
}
