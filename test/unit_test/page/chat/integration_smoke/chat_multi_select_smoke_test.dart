// test/unit_test/page/chat/integration_smoke/chat_multi_select_smoke_test.dart
//
// W3-K 本地冒烟锚（RUN_ID=chat-multi-20261111）——
// integration_test/chat_multi_select_test.dart 的 widget 级本地版：
// 真机旅程的关键生产路径（W1-A 多选状态机 + W2-E action bar + rollout
// flag 判定）在本机无设备环境全绿；真机版共享
// integration_test/helpers/chat_multi_fixtures.dart fixtures。

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show Message, MessageStatus, TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart' as domain;
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
// W5-G1 G1-7：traits 提取移至 services/message_selection_traits.dart。
import 'package:imboy/page/chat/chat/services/message_selection_traits.dart';
// W5-G1 G1-9/G1-6：多选接线抽离 + post-frame 对账器。
import 'package:imboy/page/chat/chat/chat_multi_select_wiring.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/page/chat/send_to/send_to_page.dart';
import 'package:imboy/page/chat/widget/message_multi_select_action_bar.dart';
import 'package:imboy/service/message_type_constants.dart';

import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';

/// G1-6 对账测试载体：复刻 ChatMultiSelectPanel 的注册形态 —— build 内
/// schedulePostFrame，每次重建重新注册（模拟选中态变化引起的 panel 重建）。
/// reconciler 的 existingMessageIds 指向可变集合，等价于 chatService.messages
/// 被直接变更（removeMessage/revoke 路径），而 ChatState.messages 镜像事件
/// （ref.listen 路径 1）不触发。
class _ReconcileHarness extends ConsumerStatefulWidget {
  const _ReconcileHarness({required this.reconciler});

  final ChatMultiSelectReconciler reconciler;

  @override
  ConsumerState<_ReconcileHarness> createState() => _ReconcileHarnessState();
}

class _ReconcileHarnessState extends ConsumerState<_ReconcileHarness> {
  /// 强制重建：等价于 panel 因选中态变化重建后重新注册 post-frame 对账。
  void bump() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // 与 ChatMultiSelectPanel 同构：watch 保活 autoDispose family，且选中
    // 态变化 → 本 harness 重建 → 重新注册 post-frame 对账（真实闭环）。
    ref.watch(messageSelectionProvider(widget.reconciler.conversationUk3));
    widget.reconciler.schedulePostFrame(context, ref);
    return const SizedBox.shrink();
  }
}

class _FakeChatService implements SqliteChatService {
  List<Message> items = [];
  @override
  List<Message> get messages => items;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatNotifier extends ChatNotifier {
  _FakeChatNotifier(this.service);
  final _FakeChatService service;
  @override
  ChatState build() => const ChatState();
  @override
  SqliteChatService get chatService => service;
}

void main() {
  group('W3-K 冒烟 | 多选状态机（W1-A 真实现，设备旅程⑤⑥⑦的本地锚）', () {
    test('enter → toggle → 计数；clear 清空保持激活；exit 退出', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const uk3 = 'C2C_w3k_sel';
      final notifier = container.read(messageSelectionProvider(uk3).notifier);

      final msgs = ChatMultiMessageFixtures.standardSet(
        authorId: 'w3k-peer',
        textMarker: 'w3k',
      );
      final traits = messageSelectionTraitsOf(msgs.first);
      expect(
        evaluateMessageSelectability(traits).selectable,
        isTrue,
        reason: '标准 fixtures 首条（text）应可选',
      );

      expect(notifier.enter(msgs[0].id, traits), isNull);
      var state = container.read(messageSelectionProvider(uk3));
      expect(state.active, isTrue);
      expect(state.count, 1);

      expect(
        notifier.toggle(msgs[2].id, messageSelectionTraitsOf(msgs[2])),
        isNull,
      );
      state = container.read(messageSelectionProvider(uk3));
      expect(state.count, 2);

      notifier.clear();
      state = container.read(messageSelectionProvider(uk3));
      expect(state.count, 0);
      expect(state.active, isTrue, reason: '全不选应保持多选激活（W2-E 语义）');

      notifier.exit();
      state = container.read(messageSelectionProvider(uk3));
      expect(state.active, isFalse);
    });

    test('100 条上限：第 101 条 toggle 拒绝并返回 limit_exceeded', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const uk3 = 'C2C_w3k_limit';
      final notifier = container.read(messageSelectionProvider(uk3).notifier);

      const traits = MessageSelectionTraits(
        msgType: 'text',
        status: domain.MessageStatus.sent,
      );
      expect(notifier.enter('m0', traits), isNull);
      for (var i = 1; i <= 99; i++) {
        expect(notifier.toggle('m$i', traits), isNull, reason: '第 $i 条应接受');
      }
      expect(
        container.read(messageSelectionProvider(uk3)).count,
        MessageSelectionNotifier.maxSelectionCount,
      );
      final reason = notifier.toggle('m101', traits);
      expect(
        reason,
        MessageSelectionReason.limitExceeded,
        reason: '第 101 条应拒绝（冻结合同 §4.2）',
      );
    });

    test('reconcile 清理失效 id，激活态保留', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const uk3 = 'C2C_w3k_reconcile';
      final notifier = container.read(messageSelectionProvider(uk3).notifier);
      const traits = MessageSelectionTraits(
        msgType: 'text',
        status: domain.MessageStatus.sent,
      );
      notifier.enter('keep-1', traits);
      notifier.toggle('gone-1', traits);
      notifier.reconcile(['keep-1', 'other']);
      final state = container.read(messageSelectionProvider(uk3));
      expect(state.contains('gone-1'), isFalse, reason: '已删除消息应被对账移除');
      expect(state.contains('keep-1'), isTrue);
      expect(state.active, isTrue);
    });

    test('不可选消息：E2EE 失败占位 / 阅后即焚 / WebRTC 拒绝（稳定 reason）', () {
      final e2ee = evaluateMessageSelectability(
        const MessageSelectionTraits(
          msgType: 'text',
          status: domain.MessageStatus.sent,
          e2eeFailed: true,
        ),
      );
      expect(e2ee.selectable, isFalse);
      expect(e2ee.reasonCode, MessageSelectionReason.e2eeFailed);

      final burn = evaluateMessageSelectability(
        const MessageSelectionTraits(
          msgType: 'text',
          status: domain.MessageStatus.sent,
          burnReadAt: 123,
        ),
      );
      expect(burn.selectable, isFalse);
      expect(burn.reasonCode, MessageSelectionReason.burnAfterRead);

      final rtc = evaluateMessageSelectability(
        MessageSelectionTraits(
          msgType: MessageType.webrtcAudio,
          status: domain.MessageStatus.sent,
        ),
      );
      expect(rtc.selectable, isFalse);
      expect(rtc.reasonCode, MessageSelectionReason.webrtcCall);
    });
  });

  group('W3-K 冒烟 | 多选操作', () {
    testWidgets('顶部计数与转发方式弹层保持选中消息', (tester) async {
      final selected = ChatMultiMessageFixtures.standardSet(
        authorId: 'w3k-peer',
        textMarker: 'w3k',
      );
      List<Message>? sent;
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              appBar: MessageMultiSelectHeader(
                count: selected.length,
                onCancel: () {},
              ),
              bottomNavigationBar: MessageMultiSelectActionBar(
                selectedMessages: selected,
                onForwardEach: (m) => sent = m,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(ChatMultiKeys.count), findsOneWidget);
      await tester.tap(find.byKey(ChatMultiKeys.forward));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatMultiKeys.forwardEach));
      await tester.pumpAndSettle();
      expect(sent, same(selected));
    });
  });

  testWidgets('真实多选面板弹层期间消息变为不可选时不打开发送页', (tester) async {
    const uk3 = 'C2C_sheet_live_change';
    final service = _FakeChatService();
    final original = TextMessage(id: 'm1', authorId: 'peer', text: 'original');
    service.items = [original];
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => _FakeChatNotifier(service))],
    );
    addTearDown(container.dispose);
    var resolverCalls = 0;
    final actions = ChatMultiSelectActions(
      conversationUk3: uk3,
      sourceChatType: 'C2C',
      conversationTitle: 'test',
      peerId: 'peer',
      messageActionHandlerResolver: () {
        resolverCalls++;
        throw StateError('sending must not start');
      },
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            builder: AppLoading.init(),
            home: Scaffold(
              bottomNavigationBar: ChatMultiSelectPanel(
                conversationUk3: uk3,
                actions: actions,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      container
          .read(messageSelectionProvider(uk3).notifier)
          .enter(original.id, messageSelectionTraitsOf(original)),
      isNull,
    );
    await tester.pump();
    await tester.tap(find.byKey(ChatMultiKeys.forward));
    await tester.pumpAndSettle();
    service.items = [
      TextMessage(
        id: 'm1',
        authorId: 'peer',
        text: 'placeholder',
        metadata: const {'_e2ee_failed': true},
      ),
    ];
    await tester.tap(find.byKey(ChatMultiKeys.forwardEach));
    await tester.pump();
    expect(resolverCalls, 0);
    expect(find.byType(SendToPage), findsNothing);
    expect(container.read(messageSelectionProvider(uk3)).active, isTrue);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 3));
  });

  group('W3-K 冒烟 | rollout flag 判定（设备旅程②的本地锚）', () {
    test('chat_multi_select_v1 默认 false；replaceSnapshotForTest 可开启', () {
      expect(
        AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.multiSelect),
        isFalse,
        reason: 'rollout flag 默认关闭（fail-closed，冻结合同 §4.1）',
      );

      final override = ChatMultiFlagOverride()..enableAll();
      try {
        expect(
          AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.multiSelect),
          isTrue,
        );
        expect(
          AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.historyBundle),
          isTrue,
        );
        expect(
          AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.exportShare),
          isTrue,
        );
      } finally {
        override.restore();
      }

      expect(
        AppFeatureRegistry.isRolloutFlagEnabled(ChatMultiFlags.multiSelect),
        isFalse,
        reason: 'restore 后应回到关闭态',
      );
    });
  });

  group('W5-G1 | 接线抽离（G1-9）行为锚：排序与逐条转发策略', () {
    test('sortMultiSelectMessages：createdAt 旧→新，同时间按列表稳定序', () {
      final sameTime = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final selection = MessageSelectionState(
        active: true,
        selectedIds: const {'s1', 's2', 's3'},
      );
      // 列表序（下标稳定序基准）：s1(新) s2(旧) s3(与 s1 同时间)。
      final messages = <Message>[
        TextMessage(
          id: 's1',
          authorId: 'p',
          text: '1',
          createdAt: sameTime.add(const Duration(hours: 1)),
        ),
        TextMessage(
          id: 's2',
          authorId: 'p',
          text: '2',
          createdAt: sameTime.subtract(const Duration(hours: 1)),
        ),
        TextMessage(id: 's3', authorId: 'p', text: '3', createdAt: sameTime),
      ];
      final sorted = sortMultiSelectMessages(selection, messages);
      expect(sorted.map((m) => m.id).toList(), ['s2', 's3', 's1']);
      expect(sortMultiSelectMessages(selection, const []), isEmpty);
    });

    test('弹层期间选择改变则不复用旧消息', () {
      TextMessage message(String id) =>
          TextMessage(id: id, authorId: 'p', text: id);
      expect(
        sameSelectedMessages(
          [message('a'), message('b')],
          [message('a'), message('b')],
        ),
        isTrue,
      );
      expect(
        sameSelectedMessages([message('a')], [message('a'), message('b')]),
        isFalse,
      );
      expect(
        sameSelectedMessages(
          [message('b'), message('a')],
          [message('a'), message('b')],
        ),
        isFalse,
      );
    });

    test('弹层期间同 ID 消息状态变化时禁止发送', () {
      final original = TextMessage(id: 'a', authorId: 'p', text: 'original');
      bool allowed(Message latest) => canDispatchSelectedMessages(
        active: true,
        current: [latest],
        initial: [original],
        allowed: forwardEachActionAllowedFor,
      );
      expect(allowed(original), isTrue);
      for (final metadata in [
        {'_e2ee_failed': true},
        {'burn_read_at': 1},
        {'msg_type': 'revoke'},
        {'msg_type': 'unsupported-new-type'},
      ]) {
        final latest = TextMessage(
          id: 'a',
          authorId: 'p',
          text: 'changed',
          metadata: metadata,
        );
        expect(allowed(latest), isFalse, reason: '$metadata must fail closed');
      }
      expect(
        allowed(
          TextMessage(
            id: 'a',
            authorId: 'p',
            text: 'pending',
            status: MessageStatus.sending,
          ),
        ),
        isFalse,
      );
      expect(
        canDispatchSelectedMessages(
          active: false,
          current: [original],
          initial: [original],
          allowed: forwardEachActionAllowedFor,
        ),
        isFalse,
      );
    });

    test('forwardEachActionAllowedFor：≤kBatchForwardMaxMessages 可用', () {
      const traits = MessageSelectionTraits(
        msgType: 'text',
        status: domain.MessageStatus.sent,
      );
      expect(
        forwardEachActionAllowedFor(List.filled(51, traits).map((t) => t)),
        isFalse,
      );
      expect(
        forwardEachActionAllowedFor(List.filled(50, traits).map((t) => t)),
        isTrue,
      );
      expect(forwardEachActionAllowedFor(const []), isFalse);
    });
  });

  group('W5-G1 | post-frame 对账（G1-6：remove/revoke 不回写镜像也能收敛）', () {
    testWidgets('chatService 直改（无镜像事件）：选区下一帧收敛且不循环', (tester) async {
      const uk3 = 'C2C_g1_reconcile';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 模拟 chatService.messages：removeMessage 移除 m2（不回写镜像）。
      final existing = <String>{'m1', 'm2'};
      final reconciler = ChatMultiSelectReconciler(
        conversationUk3: uk3,
        existingMessageIds: () => existing.toList(growable: false),
      );

      // 先挂 harness（watch 生效，autoDispose 常驻）再写入选中态 —— 与真实
      // panel 一致：激活前 provider 已被页面 watch 保活。
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _ReconcileHarness(reconciler: reconciler)),
        ),
      );
      await tester.pump();

      // 选中 m1/m2（enter 契约激活多选）。
      const traits = MessageSelectionTraits(
        msgType: 'text',
        status: domain.MessageStatus.sent,
      );
      final notifier = container.read(messageSelectionProvider(uk3).notifier);
      expect(notifier.enter('m1', traits), isNull);
      expect(notifier.toggle('m2', traits), isNull);
      // 选中态变化 → harness 重建重新注册 post-frame；下一帧对账无失效 id。
      await tester.pump();
      expect(container.read(messageSelectionProvider(uk3)).count, 2);

      // removeMessage 路径：m2 从 chatService.messages 消失（无镜像事件），
      // panel 因选中态/其它状态重建 → 注册的 post-frame 对账把 m2 移除。
      existing.remove('m2');
      tester
          .state<_ReconcileHarnessState>(find.byType(_ReconcileHarness))
          .bump();
      await tester.pump();
      final state = container.read(messageSelectionProvider(uk3));
      expect(state.contains('m2'), isFalse, reason: '失效选中项应在对账后收敛');
      expect(state.contains('m1'), isTrue);
      expect(state.active, isTrue, reason: '对账保持激活态（W1-A 契约）');

      // 再排两帧：无脏变更后不再写 state（收敛，无 rebuild 循环/异常）。
      await tester.pump();
      await tester.pump();
      final settledCount = container.read(messageSelectionProvider(uk3)).count;
      expect(settledCount, 1);
      expect(tester.takeException(), isNull);
      // 收尾：卸载 harness（停掉 post-frame 注册）并排帧 flush 末次 read
      // 触发的 riverpod autoDispose 调度（Duration.zero FakeTimer），
      // 避免「A Timer is still pending」。
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
    });

    testWidgets('未激活（从未 enter）：post-frame 对账 no-op 且无异常', (tester) async {
      const uk3 = 'C2C_g1_reconcile_inactive';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reconciler = ChatMultiSelectReconciler(
        conversationUk3: uk3,
        existingMessageIds: () => const <String>[],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _ReconcileHarness(reconciler: reconciler)),
        ),
      );
      await tester.pump();
      tester
          .state<_ReconcileHarnessState>(find.byType(_ReconcileHarness))
          .bump();
      await tester.pump();
      // 退出多选后残留注册同样走该 no-op 分支（active=false）。
      final state = container.read(messageSelectionProvider(uk3));
      expect(state.active, isFalse);
      expect(state.count, 0);
      expect(tester.takeException(), isNull);
      // 同上：卸载 + 排帧 flush。
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
    });
  });
}
