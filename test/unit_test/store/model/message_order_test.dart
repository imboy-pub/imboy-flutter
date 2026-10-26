// R07 phase1 排序基建测试：ConversationOrder 比较器规则 + SQL 同构。
//
// 规则（lib/store/model/message_order.dart 文件头）：
//   1. 无 seq 历史消息组整体在前；
//   2. 有 seq 组内按 conv_seq；
//   3. 回退键 accepted_at ?? created_at；
//   4. msg_id；5. auto_id 兜底（全序、可重复）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/message_order.dart';

MessageOrderKey _k({
  int? convSeq,
  int? acceptedAt,
  required int createdAt,
  required int id,
  required int autoId,
}) => (
  convSeq: convSeq,
  acceptedAt: acceptedAt,
  createdAt: createdAt,
  id: id,
  autoId: autoId,
);

void main() {
  group('ConversationOrder.compareAsc 规则', () {
    test('规则1：无 seq 历史消息整体排在有 seq 消息之前（不散插权威段）', () {
      // 无 seq 旧消息 created_at=1750000000000；有 seq 新消息 created_at 更早
      // 也仍排其后——组次序优先于时间轴。
      final legacy = _k(createdAt: 1750000000000, id: 1, autoId: 99);
      final authoritative = _k(
        convSeq: 1,
        createdAt: 1750000000001,
        id: 2,
        autoId: 100,
      );
      expect(ConversationOrder.compareAsc(legacy, authoritative), isNegative);
      expect(ConversationOrder.compareAsc(authoritative, legacy), isPositive);
    });

    test('规则2：有 seq 组内按 conv_seq 升序（与写入顺序无关）', () {
      final a = _k(convSeq: 2, createdAt: 1750000000000, id: 1, autoId: 1);
      final b = _k(convSeq: 10, createdAt: 1750000000000, id: 2, autoId: 2);
      expect(ConversationOrder.compareAsc(a, b), isNegative);
      // 离线乱序到达：auto_id 大的 seq 反而小 → seq 权威
      final lateArrived = _k(
        convSeq: 1,
        createdAt: 1750000000000,
        id: 3,
        autoId: 9,
      );
      expect(ConversationOrder.compareAsc(lateArrived, a), isNegative);
    });

    test('规则3：无 seq 组内 accepted_at 优先于 created_at 作为回退键', () {
      // created_at 说 a 在前（1000 < 9999），accepted_at 说 b 在前
      // （2000 < 3000）→ 接受事实权威，b 排前
      final a = _k(acceptedAt: 3000, createdAt: 1000, id: 1, autoId: 1);
      final b = _k(acceptedAt: 2000, createdAt: 9999, id: 2, autoId: 2);
      expect(ConversationOrder.compareAsc(a, b), isPositive);
      expect(ConversationOrder.compareAsc(b, a), isNegative);
    });

    test('规则3：两列均空时回退 created_at', () {
      final a = _k(createdAt: 1000, id: 1, autoId: 5);
      final b = _k(createdAt: 1000, id: 1, autoId: 3);
      expect(ConversationOrder.compareAsc(a, b), isPositive); // autoId 兜底
      final c = _k(createdAt: 500, id: 1, autoId: 5);
      expect(ConversationOrder.compareAsc(c, a), isNegative);
    });

    test('同毫秒无 seq 组内按 msg_id 定序（可重复，不依赖 auto_id 写入序）', () {
      final a = _k(createdAt: 1750000000000, id: 7, autoId: 3);
      final b = _k(createdAt: 1750000000000, id: 9, autoId: 4);
      expect(ConversationOrder.compareAsc(a, b), isNegative);
      expect(ConversationOrder.compareAsc(b, a), isPositive);
    });

    test('全序性与可重复性：任意 shuffle 后排序结果唯一', () {
      final rows = <MessageOrderKey>[
        _k(createdAt: 1000, id: 1, autoId: 1),
        _k(createdAt: 1000, id: 2, autoId: 2),
        _k(convSeq: 1, acceptedAt: 3000, createdAt: 3000, id: 3, autoId: 3),
        _k(convSeq: 2, createdAt: 2000, id: 4, autoId: 4),
        _k(acceptedAt: 1500, createdAt: 900, id: 5, autoId: 5),
        _k(convSeq: 3, createdAt: 2500, id: 6, autoId: 6),
      ];
      List<int> idsOf(List<MessageOrderKey> l) => l.map((e) => e.id).toList();
      final first = idsOf(rows.toList()..sort(ConversationOrder.compareAsc));
      for (var i = 0; i < 20; i++) {
        rows.shuffle();
        expect(idsOf(rows.toList()..sort(ConversationOrder.compareAsc)), first);
      }
      // 期望序：无 seq 组按 (accepted??created, id)：5(1500) < 1(1000)？
      // 5 的接受时间 1500 > 1 的 1000 → 1,2(1000,id升序),5(1500)，再 seq 组 1,2,3
      expect(first, [1, 2, 5, 3, 4, 6]);
    });

    test('不同会话 seq 互不可比：本比较器不含会话维度，调用方必须保证同会话内使用', () {
      // 文档性断言：比较器签名不含会话键；此处仅锁定签名形状防回归。
      // （跨会话使用结果无定义——由调用方契约保证，见文件头说明。）
      expect(
        ConversationOrder.compareAsc,
        isA<int Function(MessageOrderKey, MessageOrderKey)>(),
      );
    });
  });

  group('ConversationOrder SQL 片段', () {
    test('orderByAsc 含五键且列名使用常量', () {
      final sql = ConversationOrder.orderByAsc;
      expect(
        sql,
        contains('(CASE WHEN conv_seq IS NULL THEN 0 ELSE 1 END) ASC'),
      );
      expect(sql, contains('COALESCE(conv_seq, 0) ASC'));
      expect(sql, contains('COALESCE(accepted_at, created_at) ASC'));
      expect(sql, contains('id ASC'));
      expect(sql, contains('auto_id ASC'));
    });

    test('orderByDesc 是逐键取反而非字符串逆序', () {
      expect(
        ConversationOrder.orderByDesc,
        contains('CASE WHEN conv_seq IS NULL THEN 0 ELSE 1 END) DESC'),
      );
      expect(
        ConversationOrder.orderByDesc,
        contains('COALESCE(conv_seq, 0) DESC'),
      );
      expect(ConversationOrder.orderByDesc, isNot(contains('ASC')));
    });
  });
}
