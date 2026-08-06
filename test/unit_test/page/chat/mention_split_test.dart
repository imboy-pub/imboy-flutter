/// F5-A slice-4c 准备：splitMentionIds 拆分 UI 上抛的混合 mentionIds。
///
/// 契约：`chat_input.dart:425` 对 @所有人使用字面量 `'all'`（对齐后端
/// `imboy/src/ds/mention_ds.erl:38-43`），普通 @ 传 uid 字符串。
/// splitMentionIds 将混合列表拆为 (uids, isAllSelected)，供
/// `resolveMentionsForSend` 走权限分支。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/mention_all_rules.dart';

void main() {
  group('splitMentionIds', () {
    test('空列表 → isAllSelected=false, uids=[]', () {
      final r = splitMentionIds(const []);
      expect(r.isAllSelected, isFalse);
      expect(r.uids, isEmpty);
    });

    test('仅普通 uid → isAllSelected=false, uids 原样', () {
      final r = splitMentionIds(const ['u1', 'u2']);
      expect(r.isAllSelected, isFalse);
      expect(r.uids, const ['u1', 'u2']);
    });

    test('仅 "all" 字面量 → isAllSelected=true, uids=[]', () {
      final r = splitMentionIds(const ['all']);
      expect(r.isAllSelected, isTrue);
      expect(r.uids, isEmpty);
    });

    test('混合：all + 普通 uid → isAllSelected=true, uids 保留普通 uid', () {
      final r = splitMentionIds(const ['u1', 'all', 'u2']);
      expect(r.isAllSelected, isTrue);
      expect(r.uids, const ['u1', 'u2']);
    });

    test('"all" 出现多次 → isAllSelected=true（幂等）', () {
      final r = splitMentionIds(const ['all', 'u1', 'all']);
      expect(r.isAllSelected, isTrue);
      expect(r.uids, const ['u1']);
    });

    test('大小写敏感：只识别精确 "all"（防误伤包含 all 的 uid）', () {
      // uid 是 TSID 数字字符串，不会碰撞；但防御真实 uid 等于 "All" / "ALL"
      final r = splitMentionIds(const ['All', 'ALL', 'ball', 'all']);
      expect(r.isAllSelected, isTrue);
      expect(r.uids, const ['All', 'ALL', 'ball']);
    });
  });
}
