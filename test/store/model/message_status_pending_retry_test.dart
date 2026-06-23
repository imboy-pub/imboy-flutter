import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/message_model.dart';

MessageModel _msg(int status) => MessageModel(
  'm1',
  autoId: 1,
  type: 'C2C',
  status: status,
  fromId: 1,
  toId: 2,
  payload: const {'text': 'hi'},
  isAuthor: 1,
  conversationUk3: 'c2c_1_2',
);

/// 消息状态机「待重试」中间态（pendingRetry）测试。
///
/// 语义：消息发送失败后已入队、等待自动重试（介于 sending 与 error 之间）。
/// 此前流转 sending → error 直达，UI 无法区分"彻底失败"与"排队待重试"。
void main() {
  group('IMBoyMessageStatus.pendingRetry 中间态', () {
    test('常量存在且与 sending / error 区分开', () {
      expect(IMBoyMessageStatus.pendingRetry, isA<int>());
      expect(
        IMBoyMessageStatus.pendingRetry,
        isNot(IMBoyMessageStatus.sending),
      );
      expect(IMBoyMessageStatus.pendingRetry, isNot(IMBoyMessageStatus.error));
      expect(IMBoyMessageStatus.pendingRetry, isNot(IMBoyMessageStatus.sent));
    });

    test('isPendingRetryStatus 正确判定', () {
      expect(
        IMBoyMessageStatus.isPendingRetryStatus(
          IMBoyMessageStatus.pendingRetry,
        ),
        isTrue,
      );
      expect(
        IMBoyMessageStatus.isPendingRetryStatus(IMBoyMessageStatus.sending),
        isFalse,
      );
      expect(IMBoyMessageStatus.isPendingRetryStatus(null), isFalse);
    });

    test('在制中（in-flight）判定包含 pendingRetry', () {
      // 待重试属于"未终结"状态，应被视为在制中（仍可能转 sent/error）
      expect(
        IMBoyMessageStatus.isInFlightStatus(IMBoyMessageStatus.pendingRetry),
        isTrue,
      );
      expect(
        IMBoyMessageStatus.isInFlightStatus(IMBoyMessageStatus.sent),
        isFalse,
      );
    });

    test('typesStatus: pendingRetry 归入 sending（时钟），不渲染为 error（红叉）', () {
      expect(
        _msg(IMBoyMessageStatus.pendingRetry).typesStatus,
        MessageStatus.sending,
      );
      // 对照：sending 同样是 sending，error 仍是 error
      expect(
        _msg(IMBoyMessageStatus.sending).typesStatus,
        MessageStatus.sending,
      );
      expect(_msg(IMBoyMessageStatus.error).typesStatus, MessageStatus.error);
    });
  });
}
