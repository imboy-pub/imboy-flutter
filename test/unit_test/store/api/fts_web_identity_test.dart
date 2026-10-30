import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/search/web_search_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  String body =
      '{"code":0,"msg":"success","payload":{"total":2,"list":[{"message_id":9007199254740992,"from":9007199254740992,"to":9007199254740993,"conversation_type":"c2c","payload":{"text":"a","id":9007199254740995}},{"message_id":9007199254740993,"from":9007199254740993,"group_id":9007199254740995,"conversation_type":"c2g","payload":{"text":"b"}}]}}';
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  test('raw FTS identities, filter and route retain adjacent IDs', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    final encode = base64Url.encode;
    final token =
        '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.${encode(utf8.encode('synthetic'))}';
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secure,
          (call) async =>
              call.method == 'read' && call.arguments['key'] == 'secure_token'
              ? token
              : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, null),
    );
    final adapter = _Adapter();
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    final api = FtsApi.to;
    final all = (await api.searchMessages(keyword: 'a'))!.items;
    expect(all[0].id, '9007199254740992');
    expect(all[0].fromId, '9007199254740992');
    expect(all[0].toId, '9007199254740993');
    expect(all[1].toId, '9007199254740995');
    expect(
      searchMessageRoute(all[0].toId, all[0].type),
      '/chat/9007199254740993',
    );
    expect(
      searchMessageRoute(all[1].toId, all[1].type),
      '/chat/9007199254740995?type=C2G',
    );
    adapter.body = '{"code":0,"msg":"success","payload":{"total":1,"list":[{"message_id":9007199254740993,"from":1001,"from_id":1001,"group_id":9007199254740993,"to_id":9007199254740993,"conversation_type":"c2g","payload":{"text":"b"}}]}}';
    final scoped = (await api.searchConversationMessages(
      keyword: 'a',
      conversationUk3: 'C2G_1001_9007199254740993',
    ))!.items;
    expect(scoped[0].toId, '9007199254740993');
    expect(
      adapter.request!.queryParameters['conversation_id'].toString(),
      '9007199254740993',
    );
    adapter.body = '{"code":0,"msg":"success","payload":{"total":2,"list":[{"message_id":1,"from":1001,"to":9007199254740993,"conversation_type":"c2c"},{"message_id":2,"from":9007199254740993,"to":1001,"conversation_type":"c2c"}]}}';
    await api.searchConversationMessages(
      keyword: 'a',
      conversationUk3: 'C2C_1001_9007199254740993',
    );
    expect(adapter.request!.queryParameters['type'], 'C2C');
    expect(
      adapter.request!.queryParameters['conversation_id'].toString(),
      '9007199254740993',
    );
    adapter.body = '{"code":0,"msg":"success","payload":{"total":2,"list":[{"message_id":1,"from":1001,"group_id":9007199254740993,"conversation_type":"c2g"},{"message_id":2,"from":1001,"group_id":9,"conversation_type":"c2g"}]}}';
    await expectLater(
      api.searchConversationMessages(
        keyword: 'a',
        conversationUk3: 'C2G_1001_9007199254740993',
      ),
      throwsFormatException,
    );
    adapter.body = '{"code":0,"msg":"success","payload":{"total":2,"list":[{"message_id":1,"from":1001,"to":9007199254740993,"conversation_type":"c2c"},{"message_id":2,"from":1001,"to":9,"conversation_type":"c2c"}]}}';
    await expectLater(
      api.searchConversationMessages(
        keyword: 'a',
        conversationUk3: 'C2C_1001_9007199254740993',
      ),
      throwsFormatException,
    );
    for (final (scope, item) in [
      (
        'C2G_1001_9007199254740993',
        {
          'conversation_type': 'c2g',
          'from': '1001',
          'group_id': '9007199254740993',
          'to_id': '9',
        },
      ),
      (
        'C2C_1001_9007199254740993',
        {
          'conversation_type': 'c2c',
          'from': '1001',
          'from_id': '9',
          'to': '9007199254740993',
        },
      ),
      (
        'C2C_1001_9007199254740993',
        {
          'conversation_type': 'c2c',
          'type': 'c2g',
          'from': '1001',
          'to': '9007199254740993',
        },
      ),
    ]) {
      adapter.body = jsonEncode({
        'code': 0,
        'msg': 'success',
        'payload': {
          'total': 1,
          'list': [item],
        },
      });
      await expectLater(
        api.searchConversationMessages(keyword: 'a', conversationUk3: scope),
        throwsFormatException,
      );
    }
    final lastRequest = adapter.request;
    await expectLater(
      api.searchConversationMessages(keyword: 'a', conversationUk3: 'C2C_2_3'),
      throwsFormatException,
    );
    expect(adapter.request, same(lastRequest));
  });
  test('workspace member generations retain adjacent raw IDs', () {
    final raw = rewriteChannelIds(
      '{"payload":{"list":[{"id":1,"member_generation_id":9007199254740992,"member_start_seq":1,"latest_message":null},{"id":2,"member_generation_id":9007199254740993,"member_start_seq":1,"latest_message":null}]}}',
      ChannelResponseShape.groupWorkspace,
    );
    final payload = (jsonDecode(raw) as Map)['payload'] as Map;
    final rows = payload['list'] as List;
    expect(
      rows.map(
        (row) => WorkspaceConversationModel.fromJson(
          Map<String, dynamic>.from(row as Map),
        ).memberGenerationId,
      ),
      ['9007199254740992', '9007199254740993'],
    );
  });
}
