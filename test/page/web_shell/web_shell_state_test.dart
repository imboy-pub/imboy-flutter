/// Phase 1.1.b — Web Shell 状态 + 选中项密封变体测试
///
/// 覆盖：
/// - 默认 state 契约（currentTab=0, selectedItem=null）
/// - 4 个 sealed WebSelection 变体的相等性 + hashCode
/// - WebShellState 相等性 + copyWith 语义（含 clearSelection 优先级）
/// - sealed switch 穷尽性契约（保证未来新增变体时编译器强制更新所有消费侧）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';

void main() {
  group('WebShellState — 默认契约', () {
    test('默认 state: currentTab=0, selectedItem=null', () {
      const state = WebShellState();
      expect(state.currentTab, 0);
      expect(state.selectedItem, isNull);
    });

    test('两个默认 state 相等且 hashCode 一致', () {
      const a = WebShellState();
      const b = WebShellState();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString 包含关键字段（便于调试）', () {
      const state = WebShellState();
      expect(state.toString(), contains('currentTab: 0'));
      expect(state.toString(), contains('selectedItem: null'));
    });
  });

  group('WebShellState.copyWith — tab 切换', () {
    test('改 currentTab 不动 selectedItem', () {
      final original = WebShellState(
        currentTab: 0,
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final updated = original.copyWith(currentTab: 2);
      expect(updated.currentTab, 2);
      expect(updated.selectedItem, const ContactSelection(uid: 'u1'));
    });

    test('未传任何参数返回相等状态（不可变契约）', () {
      final original = WebShellState(
        currentTab: 1,
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final updated = original.copyWith();
      expect(updated, equals(original));
    });
  });

  group('WebShellState.copyWith — selection 变更', () {
    test('改 selectedItem 不动 currentTab', () {
      const original = WebShellState(currentTab: 1);
      final updated = original.copyWith(
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      expect(updated.currentTab, 1);
      expect(updated.selectedItem, const ContactSelection(uid: 'u1'));
    });

    test('selection 替换为新变体', () {
      final original = WebShellState(
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final updated = original.copyWith(
        selectedItem: const ChannelSelection(channelId: 'ch1'),
      );
      expect(
        updated.selectedItem,
        const ChannelSelection(channelId: 'ch1'),
      );
    });
  });

  group('WebShellState.copyWith — clearSelection 显式标志', () {
    test('clearSelection=true 强制置 null', () {
      final original = WebShellState(
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final updated = original.copyWith(clearSelection: true);
      expect(updated.selectedItem, isNull);
    });

    test('clearSelection=true 优先级高于 selectedItem 入参', () {
      final original = WebShellState(
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final updated = original.copyWith(
        selectedItem: const ContactSelection(uid: 'u2'),
        clearSelection: true,
      );
      expect(updated.selectedItem, isNull);
    });

    test('clearSelection=true 仍可同时改 currentTab', () {
      final original = WebShellState(
        currentTab: 1,
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final updated = original.copyWith(
        currentTab: 2,
        clearSelection: true,
      );
      expect(updated.currentTab, 2);
      expect(updated.selectedItem, isNull);
    });
  });

  group('WebSelection 变体相等性', () {
    test('ChatSelection: 同 peerId + chatType 相等', () {
      const a = ChatSelection(peerId: 'p1', chatType: 'C2C');
      const b = ChatSelection(peerId: 'p1', chatType: 'C2C');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('ChatSelection: 不同 peerId 不相等', () {
      const a = ChatSelection(peerId: 'p1', chatType: 'C2C');
      const b = ChatSelection(peerId: 'p2', chatType: 'C2C');
      expect(a, isNot(equals(b)));
    });

    test('ChatSelection: 不同 chatType 不相等', () {
      const a = ChatSelection(peerId: 'p1', chatType: 'C2C');
      const b = ChatSelection(peerId: 'p1', chatType: 'C2G');
      expect(a, isNot(equals(b)));
    });

    test('ContactSelection: 同 uid 相等', () {
      const a = ContactSelection(uid: 'u1');
      const b = ContactSelection(uid: 'u1');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('ChannelSelection: 同 channelId 相等', () {
      const a = ChannelSelection(channelId: 'ch1');
      const b = ChannelSelection(channelId: 'ch1');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('MineSelection: 同 section（含 null） 相等', () {
      const a = MineSelection();
      const b = MineSelection();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      const c = MineSelection(section: 'privacy');
      const d = MineSelection(section: 'privacy');
      expect(c, equals(d));
      expect(c, isNot(equals(a)));
    });

    test('跨变体不相等（即使内容相似）', () {
      const a = ContactSelection(uid: 'u1');
      const b = ChannelSelection(channelId: 'u1');
      expect(a, isNot(equals(b)));
    });
  });

  group('WebSelection sealed switch 穷尽性契约', () {
    /// 该函数测试 sealed class 的编译器强制：
    /// 如果未来新增 WebSelection 子类，此 switch 不更新会编译失败。
    String describeSelection(WebSelection sel) {
      return switch (sel) {
        ChatSelection(:final peerId, :final chatType) =>
          'chat:$chatType:$peerId',
        ContactSelection(:final uid) => 'contact:$uid',
        ChannelSelection(:final channelId) => 'channel:$channelId',
        MineSelection(:final section) => 'mine:${section ?? "overview"}',
      };
    }

    test('ChatSelection 解构正确', () {
      expect(
        describeSelection(
          const ChatSelection(peerId: 'p1', chatType: 'C2G'),
        ),
        'chat:C2G:p1',
      );
    });

    test('ContactSelection 解构正确', () {
      expect(
        describeSelection(const ContactSelection(uid: 'u1')),
        'contact:u1',
      );
    });

    test('ChannelSelection 解构正确', () {
      expect(
        describeSelection(const ChannelSelection(channelId: 'ch1')),
        'channel:ch1',
      );
    });

    test('MineSelection: section=null → overview', () {
      expect(describeSelection(const MineSelection()), 'mine:overview');
    });

    test('MineSelection: section 非 null → 透传 key', () {
      expect(
        describeSelection(const MineSelection(section: 'privacy')),
        'mine:privacy',
      );
    });
  });

  group('WebShellState 相等性 + selection 联动', () {
    test('两个 state currentTab + selectedItem 都相同则相等', () {
      final a = WebShellState(
        currentTab: 1,
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final b = WebShellState(
        currentTab: 1,
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('selection 不同则 state 不相等', () {
      final a = WebShellState(
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      final b = WebShellState(
        selectedItem: const ContactSelection(uid: 'u2'),
      );
      expect(a, isNot(equals(b)));
    });

    test('currentTab 不同则 state 不相等', () {
      const a = WebShellState(currentTab: 0);
      const b = WebShellState(currentTab: 1);
      expect(a, isNot(equals(b)));
    });
  });
}
