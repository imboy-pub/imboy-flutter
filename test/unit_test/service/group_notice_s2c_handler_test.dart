/// 钉住 `handleGroupNoticeS2C` dispatcher 的副作用分派契约 —— W1.1 RED。
///
/// 与 `group_edit_s2c_handler_test.dart` 同构：解析 → fireEvent；
/// 不写本地库（本切片暂不做 announcement 本地表写入，UI 层通过事件拉 refresh）
///
/// 契约：
///   1. 合法 payload → 调用 `fireEvent(payload)`
///   2. 非法 payload → 不调用 fireEvent，仅 log
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_notice_s2c.dart';

void main() {
  group('handleGroupNoticeS2C — 分派契约', () {
    late List<GroupNoticePublishedPayload> fireCalls;
    late List<String> logs;

    setUp(() {
      fireCalls = [];
      logs = [];
    });

    Future<void> run(Map<String, dynamic> payload) {
      return handleGroupNoticeS2C(
        payload: payload,
        fireEvent: fireCalls.add,
        log: logs.add,
      );
    }

    test('合法 payload → fireEvent 被调用', () async {
      await run({
        'gid': 1,
        'notice_id': 99,
        'publisher_id': 7,
        'publisher_nickname': 'Alice',
        'title': 'T',
        'body': 'B',
      });
      expect(fireCalls, hasLength(1));
      expect(fireCalls.first.gid, 1);
      expect(fireCalls.first.noticeId, 99);
      expect(fireCalls.first.publisherNickname, 'Alice');
    });

    test('非法 payload（gid 缺失）→ 不调用 fireEvent', () async {
      await run({'notice_id': 1, 'publisher_id': 7});
      expect(fireCalls, isEmpty);
      expect(logs.any((l) => l.contains('invalid_gid')), isTrue);
    });

    test('非法 payload（notice_id=0）→ 不调用 fireEvent', () async {
      await run({'gid': 1, 'notice_id': 0, 'publisher_id': 7});
      expect(fireCalls, isEmpty);
      expect(logs.any((l) => l.contains('invalid_notice_id')), isTrue);
    });
  });
}
