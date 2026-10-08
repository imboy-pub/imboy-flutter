import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_collab_created_message.dart';

void main() {
  test('创建者按服务端消息 ID 入库，失败保留已创建资源且不修改输入', () async {
    final created = <String, dynamic>{
      'id': '123',
      'chat_message': <String, dynamic>{'id': 'groupTask_123'},
    };
    String? received;
    final success = await persistGroupCollabCreatedMessage(
      created,
      processMessage: (type, data) async {
        expect(type, 'C2G');
        received = data['id'] as String;
      },
    );
    expect(received, 'groupTask_123');
    expect(success?['id'], '123');
    final failure = await persistGroupCollabCreatedMessage(
      created,
      processMessage: (_, _) async => throw StateError('disk failure'),
    );
    expect(failure?['id'], '123');
    expect(failure?['message_status'], 'failed');
    expect(created.containsKey('message_status'), isFalse);
  });
}
