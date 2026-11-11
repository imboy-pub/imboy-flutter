// test/unit_test/page/chat/integration_smoke/chat_multi_select_smoke_test.dart
//
// W3-K 本地冒烟锚（RUN_ID=chat-multi-20261111）——
// integration_test/chat_multi_select_test.dart 的 widget 级本地版：
// 真机旅程的关键生产路径（W1-A 多选状态机 + W2-E action bar + rollout
// flag 判定）在本机无设备环境全绿；真机版共享
// integration_test/helpers/chat_multi_fixtures.dart fixtures。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/widget/message_multi_select_action_bar.dart';
import 'package:imboy/service/message_type_constants.dart';

import '../../../../../integration_test/helpers/chat_multi_fixtures.dart';

Widget _wrap(Widget child) {
  return TranslationProvider(
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
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
        status: MessageStatus.sent,
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
        status: MessageStatus.sent,
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
          status: MessageStatus.sent,
          e2eeFailed: true,
        ),
      );
      expect(e2ee.selectable, isFalse);
      expect(e2ee.reasonCode, MessageSelectionReason.e2eeFailed);

      final burn = evaluateMessageSelectability(
        const MessageSelectionTraits(
          msgType: 'text',
          status: MessageStatus.sent,
          burnReadAt: 123,
        ),
      );
      expect(burn.selectable, isFalse);
      expect(burn.reasonCode, MessageSelectionReason.burnAfterRead);

      final rtc = evaluateMessageSelectability(
        MessageSelectionTraits(
          msgType: MessageType.webrtcAudio,
          status: MessageStatus.sent,
        ),
      );
      expect(rtc.selectable, isFalse);
      expect(rtc.reasonCode, MessageSelectionReason.webrtcCall);
    });
  });

  group('W3-K 冒烟 | action bar（W2-E 真组件，设备旅程⑥⑦⑨的本地锚）', () {
    final selected = ChatMultiMessageFixtures.standardSet(
      authorId: 'w3k-peer',
      textMarker: 'w3k',
    );

    testWidgets('渲染计数与三个动作位；typed callback 收到 selectedMessages', (
      tester,
    ) async {
      List<dynamic>? forwardEachArg;
      List<dynamic>? exportArg;
      await tester.pumpWidget(
        _wrap(
          MessageMultiSelectActionBar(
            selectedMessages: selected,
            onCancel: () {},
            onClearSelection: () {},
            onForwardEach: (m) => forwardEachArg = m,
            onForwardBundle: (m) {},
            onExport: (m) => exportArg = m,
          ),
        ),
      );

      expect(find.byKey(ChatMultiKeys.count), findsOneWidget);
      expect(find.textContaining('${selected.length}'), findsWidgets);
      expect(find.byKey(ChatMultiKeys.forwardEach), findsOneWidget);
      expect(find.byKey(ChatMultiKeys.forwardBundle), findsOneWidget);
      expect(find.byKey(ChatMultiKeys.export), findsOneWidget);

      await tester.tap(find.byKey(ChatMultiKeys.forwardEach));
      await tester.pump();
      await tester.tap(find.byKey(ChatMultiKeys.export));
      await tester.pump();
      expect(forwardEachArg, same(selected), reason: '逐条转发回调收到已选列表');
      expect(exportArg, same(selected), reason: '导出回调收到已选列表');
    });

    testWidgets('callback 为 null：动作位禁用（Central Wiring 接线前的占位语义）', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          MessageMultiSelectActionBar(
            selectedMessages: selected,
            onCancel: () {},
          ),
        ),
      );
      final each = tester.widget<GestureDetector>(
        find.byKey(ChatMultiKeys.forwardEach),
      );
      expect(each.onTap, isNull, reason: '未接线时按钮不可触发任何行为');
    });

    testWidgets('cancel 退出多选；clear 清空已选', (tester) async {
      var cancelled = 0;
      var cleared = 0;
      await tester.pumpWidget(
        _wrap(
          MessageMultiSelectActionBar(
            selectedMessages: selected,
            onCancel: () => cancelled++,
            onClearSelection: () => cleared++,
          ),
        ),
      );
      await tester.tap(find.byKey(ChatMultiKeys.cancel));
      await tester.pump();
      await tester.tap(find.byKey(ChatMultiKeys.clear));
      await tester.pump();
      expect(cancelled, 1);
      expect(cleared, 1);
    });
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
}
