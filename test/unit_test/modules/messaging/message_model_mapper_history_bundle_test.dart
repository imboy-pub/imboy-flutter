import 'dart:typed_data';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_open_registry.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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

  setUp(() {
    mockSqfliteSqlcipher();
    SqliteService.setDbForTest(_Contacts());
    AttachmentOpenRegistry.resetForTest();
  });
  tearDown(() {
    AttachmentOpenRegistry.resetForTest();
    SqliteService.setDbForTest(null);
  });

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

  for (final type in ['image', 'imageMulti', 'file']) {
    test(
      '$type registers nested descriptors with the outer bundle AAD',
      () async {
        final first = _sealed('one');
        final second = _sealed('two');
        final payload = type == 'imageMulti'
            ? {
                'images': [first.payload, second.payload],
                'total': 2,
              }
            : first.payload;
        final message = await _model(_bundle(type, payload)).toTypeMessage();
        expect(message, isA<CustomMessage>());
        expect(
          AttachmentOpenRegistry.materialize(first.key, first.cipher),
          _plain,
        );
        if (type == 'imageMulti') {
          expect(
            AttachmentOpenRegistry.materialize(second.key, second.cipher),
            _plain,
          );
        }
      },
    );
  }

  for (final field in ['id', 'from', 'to', 'type']) {
    test('wrong outer $field cannot open the nested ciphertext', () async {
      final sealed = _sealed('wrong-$field');
      await _model(
        _bundle('file', sealed.payload),
        wrong: field,
      ).toTypeMessage();
      expect(
        () => AttachmentOpenRegistry.materialize(sealed.key, sealed.cipher),
        throwsA(isA<AttachmentOpenException>()),
      );
    });
  }

  test('tampered nested ciphertext fails integrity checks', () async {
    final sealed = _sealed('tampered');
    await _model(_bundle('image', sealed.payload)).toTypeMessage();
    final damaged = Uint8List.fromList(sealed.cipher)..[0] ^= 1;
    expect(
      () => AttachmentOpenRegistry.materialize(sealed.key, damaged),
      throwsA(isA<AttachmentOpenException>()),
    );
  });

  for (final bad in [
    'descriptor',
    'null-descriptor',
    'uri',
    'nested-descriptor',
    'nested-uri',
  ]) {
    test('$bad rejects the bundle without partial registry writes', () async {
      final good = _sealed('good');
      final broken = _sealed('bad');
      final badPayload = <String, dynamic>{
        ...broken.payload,
        if (bad.endsWith('descriptor')) 'attachment_descriptor': 'broken',
        if (bad == 'null-descriptor') 'attachment_descriptor': null,
        if (bad.endsWith('uri')) 'uri': 'u8001/different.bin',
      };
      final bundle = _bundle('image', good.payload);
      (bundle['entries'] as List).add({
        'msg_type': bad.startsWith('nested') ? 'imageMulti' : 'file',
        'payload': bad.startsWith('nested')
            ? {
                'images': [badPayload],
              }
            : badPayload,
      });
      final message = await _model(bundle).toTypeMessage();
      expect(message, isA<TextMessage>());
      expect(message.metadata?['error'], 'invalid_payload');
      expect(message.metadata?['entries'], isNull);
      expect(AttachmentOpenRegistry.lookup(good.key), isNull);
      expect(AttachmentOpenRegistry.lookup(broken.key), isNull);
    });
  }

  test(
    'legacy plain bundle entries remain readable without a descriptor',
    () async {
      final payload = {'uri': 'u8001/plain.png', 'name': 'plain.png'};
      final message = await _model(_bundle('image', payload)).toTypeMessage();
      expect(message, isA<CustomMessage>());
      expect((message.metadata?['entries'] as List).single['payload'], payload);
      expect(AttachmentOpenRegistry.lookup('u8001/plain.png'), isNull);
    },
  );
}

final _plain = Uint8List.fromList([1, 2, 3, 4, 5]);

class _Contacts extends Fake implements Database {
  @override
  bool get isOpen => true;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    expect(table, 'contact');
    return [
      {
        'peer_id': whereArgs!.last,
        'nickname': 'Fixture sender',
        'updated_at': 1,
      },
    ];
  }
}

({Map<String, dynamic> payload, Uint8List cipher, String key}) _sealed(
  String name,
) {
  final key = 'u8001/2026/11/$name.bin';
  final sealed = AttachmentEncryptor.seal(
    plaintext: _plain,
    bindingHash: AttachmentBinding.compute(
      messageId: 'bundle-target',
      conversationId: 'c2c:8001:8002',
      senderUid: '8001',
    ),
    attachmentId: name,
    objectKey: key,
    mime: 'application/octet-stream',
    name: '$name.bin',
    contentKey: AttachmentEncryptor.randomContentKey(),
    baseNonce: AttachmentEncryptor.randomBaseNonce(),
    chunkSize: 32,
  );
  return (
    payload: {'uri': key, 'attachment_descriptor': sealed.descriptor.toMap()},
    cipher: sealed.ciphertext,
    key: key,
  );
}

Map<String, dynamic> _bundle(String type, Map<String, dynamic> payload) => {
  'bundle_version': 1,
  'entries': [
    {'msg_type': type, 'sender_name': 'historical sender', 'payload': payload},
  ],
};

MessageModel _model(Map<String, dynamic> payload, {String? wrong}) =>
    MessageModel(
      wrong == 'id' ? 'different-id' : 'bundle-target',
      autoId: 3,
      type: wrong == 'type' ? 'C2G' : 'C2C',
      status: 20,
      fromId: wrong == 'from' ? 8003 : 8001,
      toId: wrong == 'to' ? 8003 : 8002,
      msgType: MessageType.chatHistoryBundle,
      payload: payload,
      isAuthor: 0,
      conversationUk3: 'C2C_user1_8002',
      createdAt: 1760000000000,
    );
