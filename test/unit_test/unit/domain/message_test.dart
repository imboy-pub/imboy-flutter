// Message 充血实体测试（纯 domain，fake time 注入 now）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/identity/domain/value/user_id.dart';
import 'package:imboy/modules/messaging/domain/message.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/modules/messaging/domain/value/message_id.dart';

Message _msg({
  String from = 'u1',
  String type = 'text',
  DateTime? createdAt,
  MessageStatus status = MessageStatus.sent,
}) {
  return Message(
    id: MessageId.parse('m1'),
    fromId: UserId.parse(from),
    msgType: type,
    createdAt: createdAt ?? DateTime(2026, 1, 1, 12, 0, 0),
    status: status,
  );
}

final _u1 = UserId.parse('u1');
final _base = DateTime(2026, 1, 1, 12, 0, 0);

void main() {
  group('Message.canRevoke', () {
    test('本人 + 文本 + 1 分钟内 + sent → true', () {
      final m = _msg();
      expect(
        m.canRevoke(
          currentUid: _u1,
          now: _base.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('非本人 → false', () {
      expect(
        _msg().canRevoke(currentUid: UserId.parse('u2'), now: _base),
        isFalse,
      );
    });

    test('超过 2 分钟窗 → false', () {
      expect(
        _msg().canRevoke(
          currentUid: _u1,
          now: _base.add(const Duration(minutes: 3)),
        ),
        isFalse,
      );
    });

    test('不支持的类型 → false', () {
      expect(
        _msg(type: 'e2ee').canRevoke(currentUid: _u1, now: _base),
        isFalse,
      );
    });

    test('图片类型可撤回 → true', () {
      expect(
        _msg(type: 'image').canRevoke(currentUid: _u1, now: _base),
        isTrue,
      );
    });

    test('非 sent 状态 → false', () {
      expect(
        _msg(
          status: MessageStatus.sending,
        ).canRevoke(currentUid: _u1, now: _base),
        isFalse,
      );
    });
  });

  group('Message.canEdit', () {
    test('本人 + 文本 + 10 分钟内 + sent → true', () {
      expect(
        _msg().canEdit(
          currentUid: _u1,
          now: _base.add(const Duration(minutes: 10)),
        ),
        isTrue,
      );
    });

    test('非文本类型 → false', () {
      expect(_msg(type: 'image').canEdit(currentUid: _u1, now: _base), isFalse);
    });

    test('超过 15 分钟窗 → false', () {
      expect(
        _msg().canEdit(
          currentUid: _u1,
          now: _base.add(const Duration(minutes: 16)),
        ),
        isFalse,
      );
    });
  });

  group('Message 不可变状态迁移', () {
    test('markRevoked 返回新实例且原实例不变', () {
      final m = _msg();
      final revoked = m.markRevoked();
      expect(revoked.status, MessageStatus.revoked);
      expect(m.status, MessageStatus.sent);
    });

    test('markRead 返回 seen 状态', () {
      expect(_msg().markRead().status, MessageStatus.seen);
    });
  });
}
