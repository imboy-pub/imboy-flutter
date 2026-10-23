/// 多图（imageMulti）意图模板契约测试
///
/// [ChatAttachmentHandler.pendingMessageIntent] 对 kind=imageMulti 必须产出：
/// - CustomMessage 模板，metadata.msg_type = imageMulti（出网时 getMsgFromTMsg
///   据此定 msg_type）；
/// - expected_objects 取显式传入的 N（恢复时按它校验分组完整）；
/// - intentExtra（object_index / object_meta）并入 intent 顶层，供恢复排序与回填；
/// - 模板不含任何 descriptor / content key。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/service/message_type_constants.dart';

void main() {
  ChatAttachmentHandler buildHandler({bool burnEnabled = false}) =>
      ChatAttachmentHandler(
        peerId: 'peer-1',
        conversationUk3: 'uk3-xxx',
        burnEnabled: burnEnabled,
        burnAfterMs: burnEnabled ? 5000 : 0,
        currentUserOverride: const User(id: 'u-self', name: 'Self'),
        onMessageCreated: (_) async => true,
      );

  test('imageMulti 模板：custom + msg_type，expected_objects=N，extra 进顶层', () {
    final intent = buildHandler().pendingMessageIntent(
      'm-1',
      MessageType.imageMulti,
      name: 'a.jpg',
      width: 640,
      height: 480,
      expectedObjects: 3,
      intentExtra: {
        'object_index': 1,
        'object_meta': {'name': 'a.jpg', 'width': 640, 'height': 480},
      },
    );
    expect(intent['attachment_kind'], MessageType.imageMulti);
    expect(intent['expected_objects'], 3);
    expect(intent['object_index'], 1);
    expect(intent['object_meta'], {
      'name': 'a.jpg',
      'width': 640,
      'height': 480,
    });
    expect(intent['state'], 'uploading');

    final template = intent['message_template'] as Map<String, dynamic>;
    final message = ChatAttachmentHandler.messageFromPendingTemplate(template);
    expect(message, isA<CustomMessage>());
    expect(message.id, 'm-1');
    expect(message.authorId, 'u-self');
    expect(message.metadata?['msg_type'], MessageType.imageMulti);
    expect(message.metadata?['peer_id'], 'peer-1');
    expect(template.toString(), isNot(contains('attachment_descriptor')));
  });

  test('expectedObjects 未传时沿用既有默认（video 2，其余 1）', () {
    final h = buildHandler();
    expect(h.pendingMessageIntent('v', 'video')['expected_objects'], 2);
    expect(h.pendingMessageIntent('i', 'image')['expected_objects'], 1);
    expect(
      h.pendingMessageIntent(
        'i',
        'image',
        expectedObjects: 5,
      )['expected_objects'],
      5,
      reason: '显式传入优先',
    );
  });

  test('intentExtra 默认不污染 intent（既有 kind 的键集合不变）', () {
    final intent = buildHandler().pendingMessageIntent('i', 'image');
    expect(intent.containsKey('object_index'), isFalse);
    expect(intent.containsKey('object_meta'), isFalse);
  });

  test('未知 kind 仍抛 StateError', () {
    expect(
      () => buildHandler().pendingMessageIntent('x', 'hologram'),
      throwsStateError,
    );
  });
}
