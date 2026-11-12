import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';

/// W1-A（chat_multi_select_v1）：多选状态核心状态机测试。
///
/// 契约：
/// - 只保存消息 ID 集合（不复制完整 Message）；
/// - family key = conversationUk3，跨会话互相隔离；
/// - enter/toggle/clear/exit/reconcile；
/// - 上限 100 条，第 101 条拒绝并返回 limit_exceeded；
/// - autoDispose：容器销毁/无监听者后重建为空。
void main() {
  /// 默认可选 traits（text + 已送达完成态）。
  MessageSelectionTraits okTraits({
    String? msgType,
    MessageStatus status = MessageStatus.delivered,
    bool e2eeFailed = false,
    int burnReadAt = 0,
  }) => MessageSelectionTraits(
    msgType: msgType ?? 'text',
    status: status,
    e2eeFailed: e2eeFailed,
    burnReadAt: burnReadAt,
  );

  MessageSelectionState stateOf(ProviderContainer c, String key) =>
      c.read(messageSelectionProvider(key));

  MessageSelectionNotifier notifierOf(ProviderContainer c, String key) =>
      c.read(messageSelectionProvider(key).notifier);

  group('初始状态', () {
    test('未激活且选中为空', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = stateOf(container, 'convA');
      expect(state.active, false);
      expect(state.selectedIds, isEmpty);
      expect(state.count, 0);
    });
  });

  group('enter（进入多选并选中首条）', () {
    test('激活多选并选中首条', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final result = notifierOf(container, 'convA').enter('m1', okTraits());
      expect(result, isNull, reason: '成功返回 null');
      final state = stateOf(container, 'convA');
      expect(state.active, true);
      expect(state.selectedIds, ['m1']);
      expect(state.count, 1);
    });

    test('首条不可选时返回 reason，状态保持未激活', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reason = notifierOf(
        container,
        'convA',
      ).enter('m1', okTraits(status: MessageStatus.sending));
      expect(reason, MessageSelectionReason.statusSending);
      final state = stateOf(container, 'convA');
      expect(state.active, false);
      expect(state.selectedIds, isEmpty);
    });

    test('幂等：已激活时重复 enter 同一条不报错不重复', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      expect(notifier.enter('m1', okTraits()), isNull);
      expect(notifier.enter('m1', okTraits()), isNull);
      expect(stateOf(container, 'convA').selectedIds, ['m1']);
    });

    test('已激活时 enter 新 id 等价于追加选中', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      expect(notifier.enter('m2', okTraits()), isNull);
      expect(stateOf(container, 'convA').selectedIds, ['m1', 'm2']);
    });
  });

  group('toggle（已选取消 / 未选加入）', () {
    test('未激活时 toggle 返回 inactive 且不改状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reason = notifierOf(container, 'convA').toggle('m1', okTraits());
      expect(reason, MessageSelectionReason.inactive);
      expect(stateOf(container, 'convA').active, false);
    });

    test('加入 → 再点取消', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      expect(notifier.toggle('m2', okTraits()), isNull);
      expect(stateOf(container, 'convA').selectedIds, ['m1', 'm2']);
      expect(notifier.toggle('m2', okTraits()), isNull);
      expect(stateOf(container, 'convA').selectedIds, ['m1']);
      expect(stateOf(container, 'convA').active, true);
    });

    test('不可选消息 toggle 返回稳定 reason 且不加入', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      final reason = notifier.toggle('m2', okTraits(msgType: 'redPacket'));
      expect(reason, MessageSelectionReason.paymentMessage);
      expect(stateOf(container, 'convA').selectedIds, ['m1']);
    });

    test('已选中的不可选场景（规则变化后）仍允许取消勾选', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      // 选中后消息进入发送中（UI 仍渲染勾选框），取消勾选必须可用
      final reason = notifier.toggle(
        'm1',
        okTraits(status: MessageStatus.sending),
      );
      expect(reason, isNull);
      expect(stateOf(container, 'convA').selectedIds, isEmpty);
    });
  });

  group('100/101 上限边界', () {
    test('第 101 条拒绝：limit_exceeded，且不改变已有选择', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      expect(notifier.enter('m0', okTraits()), isNull);
      for (var i = 1; i <= 99; i++) {
        final reason = notifier.toggle('m$i', okTraits());
        expect(reason, isNull, reason: '第 $i 条应成功');
      }
      expect(stateOf(container, 'convA').count, 100);
      expect(
        notifier.toggle('m100', okTraits()),
        MessageSelectionReason.limitExceeded,
      );
      expect(stateOf(container, 'convA').count, 100, reason: '拒绝后仍为 100');
      expect(
        stateOf(container, 'convA').contains('m100'),
        false,
        reason: '第 101 条未被加入',
      );
    });

    test('取消一条后可再选新的（上限按当前数量计，不按历史操作数）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m0', okTraits());
      for (var i = 1; i <= 99; i++) {
        notifier.toggle('m$i', okTraits());
      }
      notifier.toggle('m0', okTraits()); // 取消 m0 → 99 条
      expect(notifier.toggle('m100', okTraits()), isNull);
      expect(stateOf(container, 'convA').count, 100);
    });

    test('满 100 条时 enter 新 id 同样返回 limit_exceeded', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m0', okTraits());
      for (var i = 1; i <= 99; i++) {
        notifier.toggle('m$i', okTraits());
      }
      expect(
        notifier.enter('m999', okTraits()),
        MessageSelectionReason.limitExceeded,
      );
    });
  });

  group('clear / exit', () {
    test('clear 清空选择但保持多选激活', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      notifier.toggle('m2', okTraits());
      notifier.clear();
      final state = stateOf(container, 'convA');
      expect(state.active, true);
      expect(state.selectedIds, isEmpty);
    });

    test('exit 退出多选并清空', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      notifier.exit();
      final state = stateOf(container, 'convA');
      expect(state.active, false);
      expect(state.selectedIds, isEmpty);
    });

    test('未激活时 exit/clear 为无副作用 no-op', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.clear();
      notifier.exit();
      final state = stateOf(container, 'convA');
      expect(state.active, false);
      expect(state.selectedIds, isEmpty);
    });
  });

  group('reconcile（删除失效 ID）', () {
    test('保留仍存在的 ID，删除已不在会话中的 ID，保持激活', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      notifier.toggle('m2', okTraits());
      notifier.toggle('m3', okTraits());
      notifier.reconcile(const ['m2', 'm3', 'm4']);
      final state = stateOf(container, 'convA');
      expect(state.active, true);
      expect(state.selectedIds, ['m2', 'm3']);
    });

    test('传入空列表 → 全部删除', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      notifier.reconcile(const []);
      final state = stateOf(container, 'convA');
      expect(state.selectedIds, isEmpty);
      expect(state.active, true);
    });

    test('无失效 ID 时 no-op', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      final before = stateOf(container, 'convA');
      notifier.reconcile(const ['m1', 'm2']);
      expect(stateOf(container, 'convA'), same(before));
    });
  });

  group('跨会话隔离（family key = conversationUk3）', () {
    test('两个会话互不影响', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifierA = notifierOf(container, 'convA');
      final notifierB = notifierOf(container, 'convB');
      notifierA.enter('a1', okTraits());
      notifierB.enter('b1', okTraits());
      notifierB.toggle('b2', okTraits());
      expect(stateOf(container, 'convA').selectedIds, ['a1']);
      expect(stateOf(container, 'convB').selectedIds, ['b1', 'b2']);
      notifierB.exit();
      expect(stateOf(container, 'convA').active, true);
      expect(stateOf(container, 'convB').active, false);
    });

    test('A 会话打满 100 不影响 B 会话继续选择', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifierA = notifierOf(container, 'convA');
      final notifierB = notifierOf(container, 'convB');
      notifierA.enter('a0', okTraits());
      for (var i = 1; i <= 99; i++) {
        notifierA.toggle('a$i', okTraits());
      }
      expect(notifierB.enter('b1', okTraits()), isNull);
      expect(stateOf(container, 'convB').count, 1);
    });
  });

  group('autoDispose 生命周期', () {
    test('容器 dispose 后新建容器读取为初始空状态', () {
      final container1 = ProviderContainer();
      notifierOf(container1, 'convA').enter('m1', okTraits());
      expect(stateOf(container1, 'convA').active, true);
      container1.dispose();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      final state = stateOf(container2, 'convA');
      expect(state.active, false);
      expect(state.selectedIds, isEmpty);
      expect(state.count, 0);
    });

    test('无监听者后被 autoDispose 回收，重新读取为空（同容器）', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        messageSelectionProvider('convA'),
        (_, _) {},
      );
      notifierOf(container, 'convA').enter('m1', okTraits());
      expect(stateOf(container, 'convA').active, true);
      sub.close();
      await pumpEventQueue();
      final state = stateOf(container, 'convA');
      expect(state.active, false, reason: 'autoDispose 后应重建为初始状态');
      expect(state.selectedIds, isEmpty);
    });
  });

  group('状态只保存 ID（不复制完整消息）', () {
    test('selectedIds 为插入序 Set<String>，外部不可篡改内部状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m2', okTraits());
      notifier.toggle('m1', okTraits());
      final ids = stateOf(container, 'convA').selectedIds;
      expect(ids, isA<Set<String>>());
      expect(ids.toList(), ['m2', 'm1'], reason: '保持插入顺序');
      expect(
        () => ids.add('m3'),
        throwsUnsupportedError,
        reason: '暴露的集合不可变，防止外部篡改状态',
      );
      expect(stateOf(container, 'convA').contains('m3'), false);
    });
  });

  group('值相等 ==/hashCode（W5-G1 G1-5）', () {
    test('同态相等：active 与选中集合一致（插入顺序不同）即 == 且 hashCode 相同', () {
      final a = MessageSelectionState(
        active: true,
        selectedIds: {'m1', 'm2', 'm3'},
      );
      final b = MessageSelectionState(
        active: true,
        selectedIds: {'m3', 'm1', 'm2'}, // 集合相等、插入序不同
      );
      expect(a, equals(b));
      expect(b, equals(a));
      expect(a.hashCode, b.hashCode, reason: '相等对象 hashCode 必须一致');
    });

    test('初始空态彼此相等', () {
      expect(
        MessageSelectionState(),
        equals(MessageSelectionState(active: false, selectedIds: const {})),
      );
      expect(
        MessageSelectionState().hashCode,
        MessageSelectionState().hashCode,
      );
    });

    test('不同态不等：active 不同 / 选中集不同 / 子集不同', () {
      final base = MessageSelectionState(
        active: true,
        selectedIds: {'m1', 'm2'},
      );
      expect(
        MessageSelectionState(active: false, selectedIds: {'m1', 'm2'}),
        isNot(equals(base)),
        reason: 'active 不同',
      );
      expect(
        MessageSelectionState(active: true, selectedIds: {'m1', 'm3'}),
        isNot(equals(base)),
        reason: '选中集合不同',
      );
      expect(
        MessageSelectionState(active: true, selectedIds: {'m1'}),
        isNot(equals(base)),
        reason: '子集（长度不同）不等',
      );
      expect(base, isNot(equals(Object())), reason: '与非同类型对象不等');
    });

    test('no-op 路径的同一实例恒等（既有 same 断言仍成立）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = notifierOf(container, 'convA');
      notifier.enter('m1', okTraits());
      final before = stateOf(container, 'convA');
      notifier.reconcile(const ['m1', 'm2']);
      expect(stateOf(container, 'convA'), same(before));
    });
  });
}
