import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helper/sqflite_test_helper.dart';

/// W3-I / BND-04：mapper 把 chat_history_bundle 消息转成 CustomMessage，
/// bundle payload（title/entries/...）原样进 metadata 供插件渲染。
void main() {
  setUpAll(() async {
    // 与 message_model_msg_type_test 同款环境（UserRepoLocal 依赖）
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, 'user1');
    await StorageService.to.setString(
      Keys.currentUser,
      '{"uid": "user1", "nickname": "测试用户", "account": "", "email": "", '
      '"mobile": "", "avatar": "", "role": null, "gender": 0, "region": "", '
      '"sign": "", "setting": {}}',
    );
  });

  setUp(() => mockSqfliteSqlcipher());

  Map<String, dynamic> bundlePayload() => <String, dynamic>{
    'bundle_version': 1,
    'title': '产品群',
    'exported_at': 1760000000000,
    'entries': [
      {
        'msg_type': 'text',
        'sender_name': '张三',
        'sent_at': 1760000000000,
        'payload': {'text': '第一条'},
      },
      {
        'msg_type': 'image',
        'sender_name': '李四',
        'payload': {'name': 'a.png'},
      },
    ],
  };

  test('chat_history_bundle → CustomMessage，payload 原样进 metadata', () async {
    final model = MessageModel(
      'bundle_1',
      autoId: 1,
      type: 'C2C',
      status: 20, // delivered
      fromId: 8001,
      toId: 8002,
      msgType: MessageType.chatHistoryBundle,
      payload: bundlePayload(),
      isAuthor: 0,
      conversationUk3: 'C2C_user1_8002',
      createdAt: 1760000000000,
    );

    final message = await model.toTypeMessage();

    expect(message, isA<CustomMessage>());
    // 常量与冻结合同一致（发收两侧共用同一 wire 值）
    expect(MessageType.chatHistoryBundle, HistoryBundleContract.msgType);
    // metadata 原样承载 bundle 快照
    expect(message.metadata?['msg_type'], MessageType.chatHistoryBundle);
    expect(message.metadata?['bundle_version'], 1);
    expect(message.metadata?['title'], '产品群');
    expect(message.metadata?['entries'], isA<List<dynamic>>());
    expect((message.metadata?['entries'] as List).length, 2);
    // 不落 unknown 分支（unknown 分支会打 unsupported 标记）
    expect(message.metadata?['unsupported'], isNull);
    expect(message.metadata?['error'], isNull);
    expect(message.metadata?['original_type'], isNull);
  });

  test('归一化器不把 chat_history_bundle 判成 unsupported', () async {
    final model = MessageModel(
      'bundle_2',
      autoId: 2,
      type: 'C2C',
      status: 20,
      fromId: 8001,
      toId: 8002,
      msgType: MessageType.chatHistoryBundle,
      payload: bundlePayload(),
      isAuthor: 0,
      conversationUk3: 'C2C_user1_8002',
      createdAt: 1760000000000,
    );

    expect(model.effectiveMsgType, MessageType.chatHistoryBundle);
  });
}
