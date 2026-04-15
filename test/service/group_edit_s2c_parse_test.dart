/// 钉住 S2C `group_edit` payload 的纯函数解析契约 —— slice-3 RED-10。
///
/// 后端合约（`imboy/src/api/group_handler.erl:262-267`）：
///   Payload = Data#{<<"gid">> => Gid}
///   即：调用方本次更新的任意字段 + gid（必需）。
///   已知可能字段：title / avatar / introduction / type / join_limit /
///   content_limit / member_max / status / ...（动态，随后端扩展）。
///
/// 契约：
///   1. `gid` 必需：int 或可转 int 的 String，<= 0 或缺失 → `invalid_gid`
///   2. 其它字段整体 passthrough 到 `updates`（剔除 gid）—— 不做白名单
///      过滤，保留前向兼容（后端新增字段时客户端不需要同步升级解析器）
///   3. `updates` 可为空（仅包含 gid 的 payload 合法，视作 no-op）
///   4. sealed result 必须穷尽 switch
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_edit_s2c.dart';

void main() {
  group('parseGroupEditPayload — gid 校验', () {
    test('gid 为正 int → success，updates 剔除 gid', () {
      final r = parseGroupEditPayload({
        'gid': 123,
        'title': '新群名',
        'introduction': '新简介',
      });
      expect(r, isA<GroupEditPayload>());
      final p = r as GroupEditPayload;
      expect(p.gid, 123);
      expect(p.updates, {'title': '新群名', 'introduction': '新简介'});
      expect(p.updates.containsKey('gid'), isFalse);
    });

    test('gid 为数字 String → 正确强转 int', () {
      final r = parseGroupEditPayload({
        'gid': '456',
        'title': 'hello',
      });
      expect(r, isA<GroupEditPayload>());
      expect((r as GroupEditPayload).gid, 456);
    });

    test('gid 缺失 → invalid_gid', () {
      final r = parseGroupEditPayload({'title': 'x'});
      expect(r, isA<GroupEditParseError>());
      expect((r as GroupEditParseError).reason, 'invalid_gid');
    });

    test('gid=0 → invalid_gid（对齐后端 validate_gid/1）', () {
      final r = parseGroupEditPayload({'gid': 0, 'title': 'x'});
      expect(r, isA<GroupEditParseError>());
      expect((r as GroupEditParseError).reason, 'invalid_gid');
    });

    test('gid 为负数 → invalid_gid', () {
      final r = parseGroupEditPayload({'gid': -1});
      expect(r, isA<GroupEditParseError>());
    });

    test('gid 为非数字 String → invalid_gid', () {
      final r = parseGroupEditPayload({'gid': 'abc'});
      expect(r, isA<GroupEditParseError>());
    });
  });

  group('parseGroupEditPayload — updates passthrough', () {
    test('仅含 gid（空 updates）→ 合法，updates 为空 Map', () {
      final r = parseGroupEditPayload({'gid': 1});
      expect(r, isA<GroupEditPayload>());
      expect((r as GroupEditPayload).updates, isEmpty);
    });

    test('包含所有已知字段 → 全量 passthrough', () {
      final r = parseGroupEditPayload({
        'gid': 10,
        'title': 't',
        'avatar': 'http://x/a.png',
        'introduction': 'intro',
        'type': 1,
        'join_limit': 2,
        'content_limit': 1,
        'member_max': 500,
        'status': 1,
      });
      expect(r, isA<GroupEditPayload>());
      final p = r as GroupEditPayload;
      expect(p.updates['title'], 't');
      expect(p.updates['avatar'], 'http://x/a.png');
      expect(p.updates['introduction'], 'intro');
      expect(p.updates['type'], 1);
      expect(p.updates['join_limit'], 2);
      expect(p.updates['content_limit'], 1);
      expect(p.updates['member_max'], 500);
      expect(p.updates['status'], 1);
      expect(p.updates.length, 8); // 不含 gid
    });

    test('包含后端未来新增的未知字段 → 同样 passthrough（前向兼容）', () {
      final r = parseGroupEditPayload({
        'gid': 1,
        'future_field_x': 'yolo',
        'another_flag': true,
      });
      expect(r, isA<GroupEditPayload>());
      final p = r as GroupEditPayload;
      expect(p.updates['future_field_x'], 'yolo');
      expect(p.updates['another_flag'], true);
    });

    test('updates 返回的 Map 与入参隔离（修改副本不影响外部）', () {
      final input = <String, dynamic>{'gid': 1, 'title': 'old'};
      final r = parseGroupEditPayload(input);
      final p = r as GroupEditPayload;
      p.updates['title'] = 'mutated';
      expect(input['title'], 'old', reason: 'updates 应为独立副本');
    });
  });

  group('parseGroupEditPayload — sealed 穷尽', () {
    test('switch 必须覆盖 GroupEditPayload 和 GroupEditParseError', () {
      final results = <GroupEditParseResult>[
        parseGroupEditPayload({'gid': 1, 'title': 't'}),
        parseGroupEditPayload({'gid': 0}),
      ];
      for (final r in results) {
        final label = switch (r) {
          GroupEditPayload(:final gid) => 'ok:$gid',
          GroupEditParseError(:final reason) => 'err:$reason',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
