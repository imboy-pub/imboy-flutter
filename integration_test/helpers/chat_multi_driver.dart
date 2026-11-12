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
// SendToPage）操作真实 UI，不注入任何假数据到生产 provider；唯勾选一步
// 在真机上改走生产 provider 通道（checkbox onTap 的同源 notifier.toggle，
// 见 _toggleViaProduction），其余步骤仍全部真实 tap。
//
// 通道纪律（G6-2）：生产 provider 通道的使用**必须计数**（DEGRADED 口径）。
// 首轮进入多选必须经真实长按菜单成功（失败即 fail，不走兜底）；后续重进
// 在长按注入失效时允许生产 enter 通道兜底，但每次兜底计入
// [ChatMultiDriverRunStats.productionEnterFallback] 并 flowLog；旅程退出前
// 调 [finishChatMultiJourney] 终局对账：真实长按 0 次却发生过兜底 = fail。

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

import '../flows/test_utils.dart';
import 'chat_multi_fixtures.dart';

/// 本次 run 的驱动通道统计（G6-2：生产通道兜底不得静默掩盖真回归）。
///
/// 真机 runner 以 `--concurrency=1` 单文件单 isolate 执行，静态计数即
/// 「本次 run」口径；旅程入口调 [reset]，退出前调 [finishChatMultiJourney]
/// 对账。三个口径：
/// - [realLongPressEnterOk]：经真实长按菜单成功进入多选的次数；
/// - [productionEnterFallback]：长按失效后走生产 enter 通道兜底的次数
///   （仅允许发生在首轮真实长按成功之后的重进场景）；
/// - [productionToggleUsed]：勾选走生产 provider 通道的次数（DEV-01 以来
///   勾选步骤的既定真机策略，只进 DEGRADED 摘要不判失败）。
abstract final class ChatMultiDriverRunStats {
  /// 经真实长按菜单成功进入多选的次数。
  static int realLongPressEnterOk = 0;

  /// 生产 enter 通道兜底进入多选的次数。
  static int productionEnterFallback = 0;

  /// 勾选走生产 provider 通道的次数（既定策略，仅摘要）。
  static int productionToggleUsed = 0;

  /// 旅程入口重置（每文件单用例，重置保证跨用例互不污染）。
  static void reset() {
    realLongPressEnterOk = 0;
    productionEnterFallback = 0;
    productionToggleUsed = 0;
  }

  /// DEGRADED 摘要行（flowLog 用）。
  static String get summary =>
      'realLongPressEnterOk=$realLongPressEnterOk '
      'productionEnterFallback=$productionEnterFallback '
      'productionToggleUsed=$productionToggleUsed';
}

/// 旅程终局对账（G6-2）：chat_multi 各旅程在退出前调用。
///
/// - 真实长按进入 0 次且发生过生产通道兜底 → DEGRADED fail（兜底掩盖了
///   长按链路回归，不得静默通过）；
/// - 其余情况记录通道统计摘要；存在任一兜底时打 DEGRADED-summary 留档。
void finishChatMultiJourney(String journey) {
  flowLog('$journey 通道统计: ${ChatMultiDriverRunStats.summary}');
  if (ChatMultiDriverRunStats.realLongPressEnterOk == 0 &&
      ChatMultiDriverRunStats.productionEnterFallback > 0) {
    fail(
      'DEGRADED: $journey 全程未发生一次真实长按进入多选，却走了 '
      '${ChatMultiDriverRunStats.productionEnterFallback} 次生产通道兜底 —— '
      '兜底掩盖了长按链路回归（通道统计: ${ChatMultiDriverRunStats.summary}）',
    );
  }
  if (ChatMultiDriverRunStats.productionEnterFallback > 0 ||
      ChatMultiDriverRunStats.productionToggleUsed > 0) {
    flowLog(
      'DEGRADED-summary: $journey 存在生产通道使用'
      '（${ChatMultiDriverRunStats.summary}）—— 真机证据留档，不判失败',
    );
  }
}

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
  // 真机注入 long-press 同样会被吞/迟到（DEV-01 r4：step⑧ 重进多选时长按
  // 未弹出菜单或菜单未含「多选」入口）→ 重试 3 次，每次重新解析 finder 取
  // 最新几何，间隔跨 kDoubleTapTimeout；菜单若仍开着（上次入口 tap 被吞），
  // 重试的长按会命中介障并先关菜单，下下次自然收敛。
  var entered = false;
  for (var attempt = 1; attempt <= 3 && !entered; attempt++) {
    if (attempt > 1) await pacedWait(tester, 400);
    await settle(tester, maxSeconds: 2);
    if (!tester.any(bubble)) continue;
    await tester.longPress(bubble.first);
    await settle(tester, maxSeconds: 2);
    entered = await tapAny(tester, chatMultiMenuEntryFinders());
    if (entered) {
      ChatMultiDriverRunStats.realLongPressEnterOk++;
    } else {
      flowLog('$journey 长按进多选未成功（尝试 $attempt/3）');
    }
  }
  if (!entered) {
    // 地面真值诊断：区分三个失败面 —— flag 被运行时刷新冲掉 / 消息不可选 /
    // 长按菜单根本没开（注入被吞）。
    final flagOn = AppFeatureRegistry.isRolloutFlagEnabled(
      ChatMultiFlags.multiSelect,
    );
    final uk3 = _resolveUk3(tester);
    final anyMenu =
        tester.any(find.text('复制')) ||
        tester.any(find.text('Copy')) ||
        tester.any(find.text('转发')) ||
        tester.any(find.text('Forward'));
    var selectableInfo = 'no-message';
    core.Message? targetMessage;
    if (tester.any(bubble)) {
      final item = tester.widget<ChatMessageItem>(bubble.first);
      targetMessage = item.message;
      final d = evaluateMessageSelectability(
        messageSelectionTraitsOf(item.message),
      );
      selectableInfo =
          'selectable=${d.selectable} reason=${d.reasonCode} '
          'status=${item.message.status}';
    }
    final diag =
        '$journey 诊断: flagOn=$flagOn uk3=$uk3 menuOpen=$anyMenu '
        '$selectableInfo';
    flowLog(diag);
    // G6-2：首轮进入必须经真实长按菜单成功 —— 生产 enter 通道仅用于首轮
    // 成功后的后续进入（重进场景长按注入可能失效，DEV-01 r7 地面真值），
    // 否则兜底会静默掩盖长按链路回归。
    if (ChatMultiDriverRunStats.realLongPressEnterOk == 0) {
      await takeScreenshot(tester, 'w3k_diag_menu_without_multiselect');
      fail(
        'DEGRADED: $journey 首轮进入多选必须经真实长按菜单成功（$diag）'
        '—— 不再静默走生产 enter 通道',
      );
    }
    // 生产 enter 通道兜底（chat_page._enterMultiSelect 的同源生产函数语义：
    // messageSelectionProvider.enter —— W1-A enter 契约同款）。G6-15：
    // 返回 record 区分「场景不可用」与「已进入」，场景不可用 ≠ 已进入。
    final ProductionEnterResult viaProduction;
    if (targetMessage == null) {
      viaProduction = (entered: false, reason: '长按目标气泡不在树，无法定位消息');
    } else {
      viaProduction = _enterMultiSelectViaProduction(tester, targetMessage);
    }
    if (!viaProduction.entered) {
      await takeScreenshot(tester, 'w3k_diag_menu_without_multiselect');
      fail(
        '$journey 长按菜单未见「多选」入口 —— flag 未开启或消息不可选；'
        '生产 enter 通道亦不可用（${viaProduction.reason}；$diag）',
      );
    }
    ChatMultiDriverRunStats.productionEnterFallback++;
    flowLog(
      'DEGRADED: $journey 长按通道失效，已走生产 enter 通道进入多选'
      '（第 ${ChatMultiDriverRunStats.productionEnterFallback} 次兜底；$diag）',
    );
    entered = true;
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
/// down/up 成对交付，杜绝跨 tap 指针串扰。多匹配时取首个（getCenter 要求
/// 单元素，避免裸 StateError）。
Future<void> tapViaNewGesture(WidgetTester tester, Finder finder) async {
  final target = finder.evaluate().length > 1 ? finder.first : finder;
  final gesture = await tester.startGesture(tester.getCenter(target));
  await gesture.up();
  await gesture.removePointer();
}

/// 经独立指针 tap [finder] 并做效果校验重试（G6-3：单发 tester.tap 违背
/// 本文件指针卫生结论，统一 tapViaNewGesture + 可判定效果校验）。
///
/// - [effectCheck] 返回 true 即认为 tap 已注册并产生预期状态变化；
/// - tap 前存在性检查（G6-14 口径）：目标 0 匹配时若效果已达成则直接
///   返回（动作已生效、目标随之消失），否则 fail 带 journey/目标描述；
/// - 连续 [maxAttempts] 次效果未出现 → 截图 + DEGRADED fail。
Future<void> tapFinderWithEffect(
  WidgetTester tester,
  Finder finder, {
  required String journey,
  required String targetDescription,
  required bool Function() effectCheck,
  int maxAttempts = 3,
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    if (attempt > 1) await pacedWait(tester, 350);
    await settle(tester, maxSeconds: 2);
    if (!tester.any(finder)) {
      if (effectCheck()) return; // 动作已生效，目标随之消失。
      fail(
        'DEGRADED: $journey $targetDescription 不在树上'
        '（尝试 $attempt/$maxAttempts，效果也未出现）',
      );
    }
    await tapViaNewGesture(tester, finder);
    await settle(tester, maxSeconds: 2);
    if (effectCheck()) return;
    flowLog('$journey $targetDescription tap 未生效（尝试 $attempt/$maxAttempts）');
  }
  await takeScreenshot(tester, 'w3k_diag_tap_effect_timeout');
  fail('DEGRADED: $journey $targetDescription 重试 $maxAttempts 次后效果仍未出现');
}

/// ChatPage 的 ProviderScope 容器（不在 ChatPage 场景返回 null，如本地冒烟）。
ProviderContainer? _chatContainerOf(WidgetTester tester) {
  final pages = find.byType(ChatPage).evaluate();
  if (pages.isEmpty) return null;
  return ProviderScope.containerOf(pages.first);
}

/// ChatPage 的 conversationUk3（State 公开 getter，动态访问私有 State 类）。
String? _resolveUk3(WidgetTester tester) {
  try {
    final state = tester.state(find.byType(ChatPage).first);
    final v = (state as dynamic).conversationUk3 as String?;
    if (v != null && v.isNotEmpty) return v;
  } on Exception {
    // fallthrough
  }
  return null;
}

/// 从 chatProvider 消息列表按 id 取 Message。
core.Message? _messageById(ProviderContainer container, String messageId) {
  final msgs =
      container.read(chatProvider.notifier).chatService?.messages ??
      const <core.Message>[];
  for (final m in msgs) {
    if (m.id == messageId) return m;
  }
  return null;
}

/// 生产进入多选通道执行结果（G6-15：消除 null 双义）。
///
/// - `entered=false` + reason：场景不可用（无 ChatPage/uk3）或 enter 被拒
///   （reason 为稳定拒绝码）—— 调用方不得把这两种情况当成「已进入」；
/// - `entered=true`：enter 已执行且成功（W1-A 契约：进入即选中该消息）。
typedef ProductionEnterResult = ({bool entered, String? reason});

/// 生产进入多选通道：chat_page._enterMultiSelect 的同源生产函数语义 ——
/// 同一 messageSelectionProvider（uk3 由 ChatPage.conversationUk3 解析）、
/// 同一 traits、同一 enter（W1-A 契约：进入即选中该消息）。
ProductionEnterResult _enterMultiSelectViaProduction(
  WidgetTester tester,
  core.Message message,
) {
  final container = _chatContainerOf(tester);
  if (container == null) {
    return (entered: false, reason: '场景不可用：树上无 ChatPage provider 容器');
  }
  final uk3 = _resolveUk3(tester);
  if (uk3 == null || uk3.isEmpty) {
    return (entered: false, reason: '场景不可用：ChatPage 未解析出 conversationUk3');
  }
  final rejection = container
      .read(messageSelectionProvider(uk3).notifier)
      .enter(message.id, messageSelectionTraitsOf(message));
  if (rejection != null) {
    return (entered: false, reason: 'enter 被拒：$rejection');
  }
  return (entered: true, reason: null);
}

/// 生产勾选通道：checkbox onTap（toggleMessageSelectionWithFeedback）的
/// 同源生产函数语义 —— 同一 messageSelectionProvider、同一 traits、同一
/// toggle；仅省去指针注入这一真机上不可靠的环节。返回是否成功执行。
///
/// DEV-01 probe2 地面真值（2026-11-12 真机）：勾选框几何/Key/hitTestable
/// 全部正确、tap 命中即正确切换（after-toggle-m2 selection=[m1,m2]），
/// 但该机型注入 tap 事件交付延迟可达秒级 —— 无 tap 的 2 秒等待窗口内
/// m3 被「迟到事件」自行勾上，多次运行出现计数反向 delta（2→1）。
/// 连续快速勾选（本旅程 6+ 次）在该环境下不具备确定性，故勾选步骤改走
/// 生产 provider 通道；勾选框渲染/计数/action bar/长按菜单/转发等其余
/// 步骤仍全部经真实 UI 驱动。每次成功使用计入
/// [ChatMultiDriverRunStats.productionToggleUsed]（G6-2 DEGRADED 摘要口径）。
bool _toggleViaProduction(
  WidgetTester tester,
  String messageId, {
  bool selectOn = true,
}) {
  final container = _chatContainerOf(tester);
  if (container == null) return false;
  final uk3 = _resolveUk3(tester);
  if (uk3 == null || uk3.isEmpty) return false;
  final message = _messageById(container, messageId);
  if (message == null) return false;
  final selection = container.read(messageSelectionProvider(uk3));
  if (selectOn && selection.contains(messageId)) {
    ChatMultiDriverRunStats.productionToggleUsed++;
    return true;
  }
  container
      .read(messageSelectionProvider(uk3).notifier)
      .toggle(message.id, messageSelectionTraitsOf(message));
  ChatMultiDriverRunStats.productionToggleUsed++;
  return true;
}

/// 在多选模式下勾选某条消息（driver 只用于「选上」语义，不用于取消）。
/// 优先生产勾选通道（见 _toggleViaProduction）；无 ChatPage/uk3 场景
/// （本地冒烟假页）退回 tap 注入：点勾选框稳定 Key（44pt 触达区），
/// 兜底点气泡本体（tap-toggle）。
///
/// tap 兜底路径的真机失败模式与对策（DEV-01 probe1-3 + fix-pass1-r2 /
/// final-pass1 证据；生产勾选 GestureDetector 均无缺陷，命中即正确切换）：
/// ① tap 被吞：入场布局切换（leading 头像↔勾选框、输入区↔action bar）后
///    首个 pointer packet 在引擎边界被延迟/丢弃 —— probe1/2 入场首 tap 不
///    注册、probe3 迟到 packet 与下一 tap 一并生效（一次勾两条）。对策：
///    enter 后 flushPendingPointerPacket 牺牲 tap + 重试间隔 pacedWait
///    ≥350ms（跨 kDoubleTapTimeout 与 packet 交付窗口）。
/// ② tap 误投：fixture 图像异步解码展开令整列位移 —— tap() 取坐标时行在
///    旧位、事件命中时行已移位（probe1 同坐标两次 tap 勾中两个不同行；
///    final-pass1 前缀截图 t3 被误勾、r1 计数 2→1 误中已选行）。
///    对策：tap 前布局稳定性门（目标 rect ≥400ms 窗口两次取样一致才出手）；
///    tap 后语义校验（计数 +1 且目标框呈选中态）；误投自愈（撤销误勾行）。
/// 校验不通过即重试（重新解析 finder 取最新几何）；重试耗尽交调用方
/// expectSelectionCount 以实际计数失败 —— 不在 driver 层吞断言。
Future<void> toggleMessageSelection(
  WidgetTester tester,
  Finder bubble, {
  String? messageId,
  int maxAttempts = 3,
  String journey = 'W3K',
}) async {
  // 生产通道：确定性勾选（真机主路径）。
  if (messageId != null && _toggleViaProduction(tester, messageId)) {
    final container = _chatContainerOf(tester);
    final uk3 = _resolveUk3(tester);
    if (container != null && uk3 != null) {
      await pacedWait(tester, 120);
      await settle(tester, maxSeconds: 1);
      final f = find.byKey(chatMultiCheckboxKey(messageId));
      final checked = tester.any(f)
          ? tester.any(
              find.descendant(
                of: f,
                matching: find.byIcon(CupertinoIcons.checkmark_circle_fill),
              ),
            )
          : true;
      final inSelection = container
          .read(messageSelectionProvider(uk3))
          .contains(messageId);
      if (inSelection && checked) return;
      if (!inSelection) {
        flowLog('W3K 生产通道勾选未生效: messageId=$messageId');
        return; // 交调用方 expectSelectionCount 以实际计数失败。
      }
      // 计数/选择已 ON 但勾选框图标未亮（理论不可达）→ 继续走 tap 兜底。
    }
  }

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
    // G6-14：稳定性门取样耗尽后目标可能已不在树（列表虚拟化未构建/已滚出
    // 可视区）—— 带病 tap 会在 getCenter 抛无上下文的裸 StateError。改为
    // 显式存在性检查，0 匹配直接 fail 并带 journey/目标诊断。
    if (!tester.any(target)) {
      fail(
        'DEGRADED: $journey 勾选 tap 目标 0 匹配'
        '（messageId=$messageId attempt=$attempt/$maxAttempts）——'
        ' 目标行不在树（虚拟化未构建或已滚出），不再带病 tap',
      );
    }
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

/// 撤销误勾：勾掉所有非 [messageId] 的已勾选行。优先生产通道（与勾选
/// 同源）；无 ChatPage 场景退回 tap 注入（勾选框呈实心圈图标，且 Key 属
/// multi_select_check_ 族的行）。messageId 为 null 时不动（无法判定目标
/// 族，交调用方断言兜底）。
Future<void> undoWrongSelections(WidgetTester tester, String? messageId) async {
  if (messageId == null) return;
  final container = _chatContainerOf(tester);
  final uk3 = container == null ? null : _resolveUk3(tester);
  if (container != null && uk3 != null) {
    final selected = container
        .read(messageSelectionProvider(uk3))
        .selectedIds
        .toList();
    for (final id in selected) {
      if (id == messageId) continue;
      final message = _messageById(container, id);
      if (message == null) continue;
      flowLog('W3K 撤销误勾(生产通道): $id');
      container
          .read(messageSelectionProvider(uk3).notifier)
          .toggle(id, messageSelectionTraitsOf(message));
      await settle(tester, maxSeconds: 1);
    }
    return;
  }
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

/// 点 action bar 的某个动作键（G6-3：tapViaNewGesture + 效果校验重试）。
///
/// [effectCheck] 描述该动作的可判定后续状态变化（如 SendToPage 出现 /
/// action bar 消失 / 计数归零）；效果未出现即按 [tapFinderWithEffect]
/// 重试并最终 DEGRADED fail。[effectCheck] 为 null 时退化为「tap + settle」
/// —— 仅限效果真不可判定的场景，chat_multi 旅程一律传效果校验。
Future<void> tapActionBar(
  WidgetTester tester,
  Key key, {
  String journey = 'W3K',
  bool Function()? effectCheck,
}) async {
  final f = find.byKey(key);
  final description = 'action bar 动作 $key';
  if (effectCheck == null) {
    expect(tester.any(f), isTrue, reason: '$journey $description 应在树上');
    await tapViaNewGesture(tester, f.first);
    await settle(tester, maxSeconds: 2);
    return;
  }
  await tapFinderWithEffect(
    tester,
    f,
    journey: journey,
    targetDescription: description,
    effectCheck: effectCheck,
  );
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

  // 行定位必须限定在结果列表内：搜索框 EditableText 的文本同样命中
  // textContaining（r10 实证：ambiguous 3 widgets → getCenter 抛错）。
  final row = find
      .descendant(
        of: find.byType(Scrollable),
        matching: find.textContaining(targetDisplayTitle, findRichText: true),
      )
      .hitTestable();
  if (!tester.any(row)) {
    await takeScreenshot(tester, 'w3k_diag_target_not_listed');
    fail('$journey 目标页搜索结果无「$targetDisplayTitle」');
  }
  // 目标行 tap + 选中校验重试（真机 r8 地面真值）：行 tap 被吞时
  // _sendBatch 的 selectedContacts.isEmpty 分支会静默 pop 目标页 ——
  // 无发送、无失败痕迹。点「发送」前必须确认 sendToProvider 的选择已生效。
  int? selectedCount() {
    final container = _chatContainerOf(tester);
    if (container == null) return null;
    try {
      return container.read(sendToProvider).selectedContacts.length;
    } on Exception {
      return null;
    }
  }

  // 非 const：find.widgetWithText 是运行时构造（非 const 构造器）。
  final List<Finder> sendFinders = <Finder>[
    find.widgetWithText(CupertinoButton, '发送'),
    find.widgetWithText(CupertinoButton, 'Send'),
    find.widgetWithText(CupertinoButton, 'Senden'),
    find.text('发送'),
    find.text('Send'),
  ];
  var selected = 0;
  for (var attempt = 1; attempt <= 3; attempt++) {
    if (attempt > 1) await pacedWait(tester, 400);
    await tapViaNewGesture(tester, row);
    await settle(tester, maxSeconds: 1);
    selected = selectedCount() ?? selected;
    if (selected > 0) break;
    flowLog('$journey 目标行 tap 未生效（尝试 $attempt/3）selected=$selected');
  }
  expect(selected, greaterThan(0), reason: '$journey 目标行选择未生效（真机指针交付不可靠，重试耗尽）');

  // 点「发送」；发送 tap 被吞时页面停留 —— 按钮仍在（批量运行态按钮已变
  // 「取消」，此时绝不能重点，等协调器自行完成）即重试。
  var sent = await tapAny(tester, sendFinders);
  expect(sent, isTrue, reason: '$journey 未找到目标页发送按钮');
  for (var attempt = 1; attempt <= 3 && isOnSendToPage(tester); attempt++) {
    final stillSendButton = sendFinders.any((f) => tester.any(f));
    if (!stillSendButton) break;
    await pacedWait(tester, 800);
    if (!isOnSendToPage(tester)) break;
    flowLog('$journey 发送 tap 未生效，重试（尝试 $attempt/3）');
    await tapAny(tester, sendFinders);
  }
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
