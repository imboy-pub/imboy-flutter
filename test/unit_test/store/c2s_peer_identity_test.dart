import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PeerApi extends MsgApi {
  Map<String, dynamic>? query;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    query = queryParameters;
    return IMBoyHttpResponse.success({
      ...queryParameters!,
      'state': 'committed',
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final peer in ['bot:gpt-4', '001']) {
    test('C2S target $peer survives reopen and ACK identity check', () async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '101',
        Keys.currentUser: jsonEncode({'id': '101'}),
      });
      await StorageService.init();
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('c2s-peer-test-');
      final path = '${directory.path}/db.sqlite';
      var db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        await db.execute(
          'CREATE TABLE msg_c2s (auto_id INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE, type TEXT, from_id INTEGER, to_id INTEGER, payload TEXT, created_at INTEGER, is_author INTEGER, status INTEGER, conversation_uk3 TEXT, topic_id INTEGER, msg_type TEXT, action TEXT, e2ee TEXT)',
        );
        await db.execute(
          'CREATE TABLE attachment_upload_task (id TEXT, user_id TEXT, anchor_msg_id TEXT, business_intent TEXT)',
        );
        SqliteService.setDbForTest(db);
        final message = MessageModel(
          'c2s-id',
          autoId: 0,
          type: 'C2S',
          status: IMBoyMessageStatus.sending,
          fromId: '101',
          toId: peer,
          payload: {'text': 'hello'},
          createdAt: 1751850000000,
          isAuthor: 1,
          conversationUk3: 'c2s-101-$peer',
          msgType: 'text',
        );
        expect(message.toId, peer);
        await MessageRepo(tableName: 'msg_c2s').insert(message, outbound: true);
        await db.close();
        db = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        SqliteService.setDbForTest(db);
        final restored = (await MessageRepo(tableName: 'msg_c2s')
            .find('c2s-id'))!;
        expect(restored.toId, peer);
        final api = _PeerApi();
        expect(
          await api.isCommitted(
            chatType: 'c2s',
            peerId: restored.toId,
            messageId: restored.id,
          ),
          isTrue,
        );
        expect(api.query!['peer_id'], peer);
        expect(
          await ServerAckReceipts.persist(
            db: db,
            ackId: 'c2s-id',
            ackType: 'C2S_SERVER_ACK',
            ownerUid: '101',
            expectedAutoId: restored.autoId,
            expectedPeerId: peer,
            requireAttempt: false,
            isCurrent: () => true,
          ),
          isTrue,
        );
      } finally {
        SqliteService.setDbForTest(null);
        await db.close();
        await directory.delete(recursive: true);
      }
    });
  }
}
