/// Phase 1.1.m — Web Shell 深链参数编解码测试
///
/// 覆盖：
/// - parseShellRouteParams: 4 tab × selection 组合 + 容错降级
/// - shellStateToRouteParams: 4 tab × selection 组合 + null selection
/// - round-trip 不变性：parse(toParams(state)) == state
/// - 常量契约：tab name 与 index 双向映射一致性
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_shell_route_params.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';

void main() {
  group('parseShellRouteParams — 容错降级', () {
    test('空 map → 默认 state', () {
      expect(parseShellRouteParams({}), const WebShellState());
    });

    test('未知 tab name → 默认 state', () {
      expect(
        parseShellRouteParams({'tab': 'unknown'}),
        const WebShellState(),
      );
    });

    test('tab 大小写敏感: "Chat" 不匹配（仅小写）', () {
      expect(
        parseShellRouteParams({'tab': 'Chat'}),
        const WebShellState(),
      );
    });

    test('有 tab 缺 id → 仅恢复 currentTab，selection=null', () {
      expect(
        parseShellRouteParams({'tab': 'chat'}),
        const WebShellState(currentTab: 0),
      );
      expect(
        parseShellRouteParams({'tab': 'contact'}),
        const WebShellState(currentTab: 1),
      );
    });

    test('id 为空字符串 → 视为缺失，不构造 selection', () {
      expect(
        parseShellRouteParams({'tab': 'contact', 'id': ''}),
        const WebShellState(currentTab: 1),
      );
    });
  });

  group('parseShellRouteParams — Tab 0 ChatSelection', () {
    test('chat + id + type=C2C', () {
      final state = parseShellRouteParams({
        'tab': 'chat',
        'id': 'p1',
        'type': 'C2C',
      });
      expect(state.currentTab, 0);
      expect(
        state.selectedItem,
        const ChatSelection(peerId: 'p1', chatType: 'C2C'),
      );
    });

    test('chat + id + type=C2G', () {
      final state = parseShellRouteParams({
        'tab': 'chat',
        'id': 'group1',
        'type': 'C2G',
      });
      expect(
        state.selectedItem,
        const ChatSelection(peerId: 'group1', chatType: 'C2G'),
      );
    });

    test('chat + id 缺失 type → 默认 C2C', () {
      final state = parseShellRouteParams({'tab': 'chat', 'id': 'p1'});
      expect(
        state.selectedItem,
        const ChatSelection(peerId: 'p1', chatType: 'C2C'),
      );
    });
  });

  group('parseShellRouteParams — Tab 1 ContactSelection', () {
    test('contact + id', () {
      final state = parseShellRouteParams({
        'tab': 'contact',
        'id': 'u1',
      });
      expect(state.currentTab, 1);
      expect(state.selectedItem, const ContactSelection(uid: 'u1'));
    });

    test('contact 忽略 type 参数（只 chat 用 type）', () {
      final state = parseShellRouteParams({
        'tab': 'contact',
        'id': 'u1',
        'type': 'C2C', // 与 contact 无关，应被忽略
      });
      expect(state.selectedItem, const ContactSelection(uid: 'u1'));
    });
  });

  group('parseShellRouteParams — Tab 2 ChannelSelection', () {
    test('channel + id', () {
      final state = parseShellRouteParams({
        'tab': 'channel',
        'id': 'ch_42',
      });
      expect(state.currentTab, 2);
      expect(
        state.selectedItem,
        const ChannelSelection(channelId: 'ch_42'),
      );
    });
  });

  group('parseShellRouteParams — Tab 3 MineSelection', () {
    test('mine + id (section)', () {
      final state = parseShellRouteParams({
        'tab': 'mine',
        'id': 'privacy',
      });
      expect(state.currentTab, 3);
      expect(
        state.selectedItem,
        const MineSelection(section: 'privacy'),
      );
    });

    test('mine 缺失 id → currentTab=3 + selection=null', () {
      final state = parseShellRouteParams({'tab': 'mine'});
      expect(state.currentTab, 3);
      expect(state.selectedItem, isNull);
    });
  });

  group('shellStateToRouteParams — 编码', () {
    test('默认 state → 仅 tab=chat', () {
      expect(
        shellStateToRouteParams(const WebShellState()),
        {'tab': 'chat'},
      );
    });

    test('currentTab=2 + null selection → tab=channel', () {
      expect(
        shellStateToRouteParams(const WebShellState(currentTab: 2)),
        {'tab': 'channel'},
      );
    });

    test('ChatSelection → 输出 id + type', () {
      final state = const WebShellState(
        currentTab: 0,
        selectedItem: ChatSelection(peerId: 'p1', chatType: 'C2G'),
      );
      expect(
        shellStateToRouteParams(state),
        {'tab': 'chat', 'id': 'p1', 'type': 'C2G'},
      );
    });

    test('ContactSelection → 输出 id（不输出 type）', () {
      final state = const WebShellState(
        currentTab: 1,
        selectedItem: ContactSelection(uid: 'u1'),
      );
      expect(
        shellStateToRouteParams(state),
        {'tab': 'contact', 'id': 'u1'},
      );
    });

    test('ChannelSelection → 输出 id', () {
      final state = const WebShellState(
        currentTab: 2,
        selectedItem: ChannelSelection(channelId: 'ch1'),
      );
      expect(
        shellStateToRouteParams(state),
        {'tab': 'channel', 'id': 'ch1'},
      );
    });

    test('MineSelection(section=null) → 仅 tab', () {
      final state = const WebShellState(
        currentTab: 3,
        selectedItem: MineSelection(),
      );
      expect(
        shellStateToRouteParams(state),
        {'tab': 'mine'},
      );
    });

    test('MineSelection(section=privacy) → 输出 id=privacy', () {
      final state = const WebShellState(
        currentTab: 3,
        selectedItem: MineSelection(section: 'privacy'),
      );
      expect(
        shellStateToRouteParams(state),
        {'tab': 'mine', 'id': 'privacy'},
      );
    });

    test('MineSelection(section=空字符串) → 视为无 section，仅输出 tab', () {
      final state = const WebShellState(
        currentTab: 3,
        selectedItem: MineSelection(section: ''),
      );
      expect(
        shellStateToRouteParams(state),
        {'tab': 'mine'},
      );
    });

    test('currentTab 越界（理论不可达，但防御）→ 空 map', () {
      final state = const WebShellState(currentTab: 99);
      expect(shellStateToRouteParams(state), {});
    });
  });

  group('round-trip 不变性：parse(toParams(state)) == state', () {
    final List<WebShellState> roundTripCases = [
      const WebShellState(),
      const WebShellState(currentTab: 1),
      const WebShellState(currentTab: 2),
      const WebShellState(currentTab: 3),
      const WebShellState(
        currentTab: 0,
        selectedItem: ChatSelection(peerId: 'p1', chatType: 'C2C'),
      ),
      const WebShellState(
        currentTab: 0,
        selectedItem: ChatSelection(peerId: 'group1', chatType: 'C2G'),
      ),
      const WebShellState(
        currentTab: 1,
        selectedItem: ContactSelection(uid: 'u_42'),
      ),
      const WebShellState(
        currentTab: 2,
        selectedItem: ChannelSelection(channelId: 'ch_99'),
      ),
      const WebShellState(
        currentTab: 3,
        selectedItem: MineSelection(section: 'privacy'),
      ),
    ];

    for (final state in roundTripCases) {
      test('round-trip: $state', () {
        final params = shellStateToRouteParams(state);
        final restored = parseShellRouteParams(params);
        expect(restored, equals(state));
      });
    }
  });

  group('常量契约', () {
    test('kRouteParamTab/Id/Type', () {
      expect(kRouteParamTab, 'tab');
      expect(kRouteParamId, 'id');
      expect(kRouteParamType, 'type');
    });

    test('kRouteTabNameToIndex 4 entries 对应 0..3', () {
      expect(kRouteTabNameToIndex, hasLength(4));
      expect(kRouteTabNameToIndex['chat'], 0);
      expect(kRouteTabNameToIndex['contact'], 1);
      expect(kRouteTabNameToIndex['channel'], 2);
      expect(kRouteTabNameToIndex['mine'], 3);
    });

    test('kRouteTabIndexToName 4 entries 顺序与 NameToIndex 一致', () {
      expect(kRouteTabIndexToName, ['chat', 'contact', 'channel', 'mine']);
      // 双向映射一致性
      for (var i = 0; i < kRouteTabIndexToName.length; i++) {
        final name = kRouteTabIndexToName[i];
        expect(kRouteTabNameToIndex[name], i);
      }
    });
  });
}
