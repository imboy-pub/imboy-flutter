/// W07.c（channel-group-ux-v2.2 §6.5 C2）：清单 cursor 协议客户端纯策略测试。
/// 覆盖 J27.b 能力门精度（恰为整数 1）与协议 opt-in query 形态。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/list_cursor_client.dart';

void main() {
  group('listCursorContractEnabled（J27.b 门精度）', () {
    test('恰为整数 1 才启用', () {
      expect(listCursorContractEnabled(null), isFalse);
      expect(listCursorContractEnabled(const {}), isFalse);
      expect(listCursorContractEnabled(const {'create_request_id': 1}), isTrue);
    });

    test('true / "1" / 2 / 0 / 1.0 等一律不启用（绝不激进解释）', () {
      for (final raw in const [true, '1', 2, 0, 1.0, <String, dynamic>{}]) {
        expect(
          listCursorContractEnabled({'create_request_id': raw}),
          isFalse,
          reason: 'create_request_id=$raw (${raw.runtimeType}) 不应启用',
        );
      }
    });
  });

  group('cursorQuery（协议 opt-in 形态）', () {
    test('首页：pagination=cursor、limit、无 cursor 键', () {
      final q = cursorQuery(limit: 20);
      expect(q['pagination'], 'cursor');
      expect(q['limit'], '20');
      expect(q.containsKey('cursor'), isFalse);
      expect(q.containsKey('q'), isFalse);
    });

    test('翻页/搜索：token 与 q 条件携带', () {
      final q = cursorQuery(token: 'tok_x', limit: 50, q: '产品');
      expect(q['pagination'], 'cursor');
      expect(q['cursor'], 'tok_x');
      expect(q['q'], '产品');
    });

    test('空 token 不携带 cursor 键（首页语义）', () {
      final q = cursorQuery(token: '', limit: 50);
      expect(q.containsKey('cursor'), isFalse);
    });
  });

  test('ListCursorKind 常量与服务端 list_cursor 域一致（八族）', () {
    expect(ListCursorKind.groupOwned, 'group_owned');
    expect(ListCursorKind.groupJoined, 'group_joined');
    expect(ListCursorKind.groupManaged, 'group_managed');
    expect(ListCursorKind.channelSubscribed, 'channel_subscribed');
    expect(ListCursorKind.channelManaged, 'channel_managed');
    expect(ListCursorKind.wsGroupDirectory, 'ws_group_directory');
    expect(ListCursorKind.wsGroupMember, 'ws_group_member');
    expect(ListCursorKind.wsChannelDirectory, 'ws_channel_directory');
  });
}
