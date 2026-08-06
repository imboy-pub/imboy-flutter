import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/message_model.dart';

/// BUG#70 回归：`conversationMsgType` 的类型链漏了视频/语音/流式三种，
/// 会话列表把它们全渲染成「未知消息」（真机实测：发完视频，消息列表显示"未知消息"）。
///
/// 这些消息的 metadata 里并没有 `msg_type`（发送侧没写），所以只能靠
/// Message 子类型判断——同文件 `toPayload` 的类型链早就写全了，这里是少写的那一份。
void main() {
  const author = 'u1';
  final createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  group('conversationMsgType 覆盖所有已支持的消息子类型', () {
    test('VideoMessage → video（不是 unsupported）', () {
      final msg = VideoMessage(
        id: 'm1',
        authorId: author,
        createdAt: createdAt,
        source: 'u1/x.mp4',
        // 刻意不放 msg_type：真实发送链路就没写
        metadata: const <String, dynamic>{'peer_id': '2'},
      );
      expect(MessageModel.conversationMsgType(msg), MessageType.video);
    });

    test('AudioMessage → voice', () {
      final msg = AudioMessage(
        id: 'm2',
        authorId: author,
        createdAt: createdAt,
        source: 'u1/x.aac',
        duration: const Duration(seconds: 3),
      );
      expect(MessageModel.conversationMsgType(msg), MessageType.voice);
    });

    test('metadata 里的 msg_type 优先级仍高于子类型推断', () {
      final msg = VideoMessage(
        id: 'm3',
        authorId: author,
        createdAt: createdAt,
        source: 'u1/x.mp4',
        metadata: const <String, dynamic>{'msg_type': 'custom_thing'},
      );
      expect(MessageModel.conversationMsgType(msg), 'custom_thing');
    });
  });

  test('会话副标题：视频消息显示 [视频] 而非「未知消息」', () {
    final msg = VideoMessage(
      id: 'm4',
      authorId: author,
      createdAt: createdAt,
      source: 'u1/x.mp4',
      metadata: const <String, dynamic>{'peer_id': '2'},
    );
    expect(MessageModel.conversationSubtitle(msg), '[视频]');
  });
}
