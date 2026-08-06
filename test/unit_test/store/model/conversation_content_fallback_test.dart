import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// 会话列表副标题：未枚举消息类型不得渲染成「未知消息」。
///
/// 生产实测（群 99746135830431744）最后一条消息是 `expression`，
/// `ConversationModel.content` 的 if/else 白名单里没有这一档，
/// 于是整条会话显示「[未知消息]」—— 而它的 subtitle 明明是 `👏`。
ConversationModel _conv({required String msgType, required String subtitle}) {
  return ConversationModel(
    id: 1,
    peerId: 99746135830431744,
    avatar: '',
    title: '测试群',
    subtitle: subtitle,
    type: 'C2G',
    msgType: msgType,
    lastTime: 0,
    lastMsgId: 0,
    unreadNum: 0,
    isShow: 1,
  );
}

void main() {
  group('ConversationModel.content 对未枚举类型的兜底', () {
    test('expression 显示表情本身，不是「未知消息」', () {
      expect(_conv(msgType: 'expression', subtitle: '👏').content, '👏');
    });

    test('将来新增的未知类型只要有 subtitle 就显示 subtitle', () {
      expect(
        _conv(msgType: 'some_future_type', subtitle: '摘要文本').content,
        '摘要文本',
      );
    });

    test('未知类型且 subtitle 为空时才回落到「未知消息」占位', () {
      final content = _conv(msgType: 'some_future_type', subtitle: '').content;
      expect(content.startsWith('['), isTrue);
      expect(content.endsWith(']'), isTrue);
    });

    test('已枚举类型不受影响：image 仍显示 [图片] 而非 subtitle', () {
      final content = _conv(
        msgType: MessageType.image,
        subtitle: '不该显示这个',
      ).content;
      expect(content, isNot('不该显示这个'));
      expect(content.startsWith('['), isTrue);
    });

    test('text 仍直接显示 subtitle', () {
      expect(_conv(msgType: MessageType.text, subtitle: '你好').content, '你好');
    });
  });
}
