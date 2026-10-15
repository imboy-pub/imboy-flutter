// Real native Megolm + PFv3 + file SQLite restart; no network or device acceptance.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:imboy/config/init.dart' as app_init;
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

import '../vodozemac_native_lib.dart';

class _NativeMegolm implements E2eeSessionProtocol {
  _NativeMegolm(this.outbound, this.inbound);
  final vod.GroupSession? outbound;
  final vod.InboundGroupSession inbound;
  @override
  ProtocolSuite get suite => ProtocolSuite.megolm;
  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {}
  @override
  Future<void> clearAll() async {}
  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async => E2eeCiphertext(outbound!.encrypt(plaintext), {
    'protocol': 'megolm',
    'version': 1,
    'session_id': inbound.sessionId,
  });
  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async => inbound.decrypt(ciphertext).plaintext;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('group_cipher_row_restart_restores_sender_identity_and_decrypts_real_megolm', () async {
    await ensureVodozemac();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '101');
    await StorageService.setMap(Keys.currentUser, {
      'uid': '101',
      'nickname': 'Synthetic',
    });
    final directory = await Directory.systemTemp.createTemp(
      'imboy-outbox-identity-',
    );
    sqfliteFfiInit();
    final path = '${directory.path}/owned.sqlite';
    var db = await databaseFactoryFfi.openDatabase(path);
    SqliteService.setDbForTest(db);
    await db.execute(
      'CREATE TABLE msg_c2g (auto_id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'id TEXT, type TEXT, from_id INTEGER, to_id INTEGER, payload TEXT, created_at INTEGER,'
      'is_author INTEGER, status INTEGER, conversation_uk3 TEXT, topic_id INTEGER,'
      'msg_type TEXT, action TEXT, e2ee TEXT)',
    );
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final secure = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments as Map;
          final key = args['key'] as String;
          if (call.method == 'write') secure[key] = args['value'] as String;
          if (call.method == 'read') return secure[key];
          return null;
        });
    app_init.deviceId = 'original-device';
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    await GroupSessionService.to.setGroupE2EEMode('202', 1);
    final outbound = vod.GroupSession();
    final export = outbound.toInbound().exportAt(0)!;
    E2eeBootstrap.resetForTest();
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(
      _NativeMegolm(outbound, vod.InboundGroupSession.import(export)),
    );
    final encrypted = await E2eeOutboundRouter.encryptV3(
      suite: ProtocolSuite.megolm,
      plaintext: jsonEncode({
        'msg_type': 'file',
        'name': '原文件.bin',
        'uri': 'u101/original',
        'size': 12,
      }),
      recipients: const [],
      context: E2eeContext(gid: '202', scope: 'c2g'),
      messageId: 'original-group-id',
      senderUid: '101',
      senderDid: 'original-device',
      destination: '202',
      messageType: 'file',
      action: 'message',
      sessionRef: outbound.sessionId,
      persistOutbox: false,
    );
    final crypto = CryptoStore(db);
    await crypto.ensureSchema();
    await crypto.insertOutbox(
      id: 'original-group-id',
      payload: jsonEncode({
        'e2ee': encrypted.metadata,
        'payload': encrypted.ciphertext,
      }),
    );
    final template = FileMessage(
      id: 'original-group-id',
      authorId: '101',
      createdAt: DateTime.now().toUtc(),
      source: 'u101/original',
      name: '原文件.bin',
      size: 12,
      metadata: const {'peer_id': '202'},
    );
    final prepared = await const ChatNetworkService()
        .prepareAttachmentOutboxMessage(
          type: 'C2G',
          conversationUk3: 'C2G_202',
          message: template,
        );
    expect(prepared.payload, '');
    expect(prepared.e2ee, encrypted.metadata);
    expect(prepared.senderDid, 'original-device');
    app_init.deviceId = 'different-device';
    await expectLater(
      const ChatNetworkService().prepareAttachmentOutboxMessage(
        type: 'C2G',
        conversationUk3: 'C2G_202',
        message: template,
      ),
      throwsA(isA<E2eeSecurityException>()),
    );
    app_init.deviceId = 'original-device';
    await MessageRepo(tableName: MessageRepo.c2gTable).insert(prepared);
    await db.close();
    db = await databaseFactoryFfi.openDatabase(path);
    SqliteService.setDbForTest(db);
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(
      _NativeMegolm(null, vod.InboundGroupSession.import(export)),
    );
    try {
      final raw = (await db.query('msg_c2g')).single;
      expect(
        jsonDecode(raw['e2ee'] as String)[MessageModel.localSenderDidKey],
        'original-device',
      );
      expect(MessageModel.fromJson(raw).senderDid, isNull);
      final restored = (await MessageRepo(tableName: MessageRepo.c2gTable)
          .find(prepared.id))!;
      expect(restored.senderDid, 'original-device');
      expect(
        restored.e2ee!.containsKey(MessageModel.localSenderDidKey),
        isFalse,
      );
      final message = await restored.toTypeMessage();
      expect(message, isA<FileMessage>());
      expect((message as FileMessage).source, 'u101/original');
      expect(message.name, '原文件.bin');
      expect(
        MessageModel.outboundJson(
          jsonEncode({'e2ee': jsonDecode(raw['e2ee'] as String)}),
        ),
        isNot(contains(MessageModel.localSenderDidKey)),
      );
    } finally {
      E2eeBootstrap.resetForTest();
      E2eeProtocolRegistry.resetForTest();
      SqliteService.setDbForTest(null);
      await db.close();
      await directory.delete(recursive: true);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });
}
