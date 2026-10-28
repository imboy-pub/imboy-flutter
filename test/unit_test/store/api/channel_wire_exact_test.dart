import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({this.summaryPayload, this.fail = false});
  final String? summaryPayload;
  final bool fail;
  Object? parentId;
  int requests = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (options.path.endsWith('/comment')) {
      final data = options.data;
      final map = data is String ? jsonDecode(data) as Map : data as Map;
      parentId = map['parent_id'];
    }
    final payload = options.path.endsWith('/comments')
        ? '{"list":[{"id":9007199254740993,"channel_id":9007199254740995,"message_id":9007199254740997,"user_id":9007199254740999,"parent_id":0,"reply_to_uid":0,"content":"synthetic"}]}'
        : options.path.endsWith('/summary')
        ? summaryPayload ??
              '{"channels":[{"channel_id":9007199254740993,"unread_count":7}]}'
        : '{"id":9007199254740993,"creator_uid":9007199254740995,"name":"synthetic"}';
    return ResponseBody.fromString(
      '{"code":${fail ? 1 : 0},"msg":"${fail ? 'failed' : 'success'}","payload":$payload}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

class _Repo extends ChannelRepo {
  final changes = <String, int>{};
  @override
  Future<List<ChannelSubscriptionModel>> getAllSubscriptions() async => [
    ChannelSubscriptionModel(
      channelId: '9007199254740993',
      subscribedAt: DateTime(2025),
      unreadCount: 2,
    ),
  ];
  @override
  Future<int> updateUnreadCount(String channelId, int count) async {
    changes[channelId] = count;
    return 1;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    HttpClient.adapterForTest = _Adapter();
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  test(
    'ChannelApi decodes raw detail and unread IDs before JSON rounding',
    () async {
      final api = ChannelApi();
      final channel = await api.getChannelChecked('9007199254740993');
      expect(channel.id, '9007199254740993');
      expect(channel.creatorId, '9007199254740995');
      final summary = await api.getUnreadSummary();
      expect(
        (summary['channels'] as List).single['channel_id'],
        '9007199254740993',
      );
      expect((summary['channels'] as List).single['unread_count'], 7);
    },
  );
  test('comment API preserves all IDs for owner comparison', () async {
    final comments = await ChannelApi().getComments(
      channelId: '9007199254740995',
      messageId: '9007199254740997',
    );
    expect(comments.single.id, '9007199254740993');
    expect(comments.single.channelId, '9007199254740995');
    expect(comments.single.messageId, '9007199254740997');
    expect(comments.single.userId, '9007199254740999');
    expect(comments.single.parentId, '0');
  });
  test(
    'comment parent writes exact large ID and preserves small integer contract',
    () async {
      final adapter = _Adapter();
      HttpClient.adapterForTest = adapter;
      final api = ChannelApi();
      await api.createComment(
        channelId: '2',
        messageId: '3',
        content: 'x',
        parentId: '17',
      );
      expect(adapter.parentId, 17);
      await api.createComment(
        channelId: '2',
        messageId: '3',
        content: 'x',
        parentId: '9007199254740993',
      );
      expect(
        adapter.parentId,
        kIsWeb ? '9007199254740993' : int.parse('9007199254740993'),
      );
    },
  );
  test('old server rejection does not retry a rounded parent ID', () async {
    final adapter = _Adapter(fail: true);
    HttpClient.adapterForTest = adapter;
    final result = await ChannelApi().createComment(
      channelId: '2',
      messageId: '3',
      content: 'x',
      parentId: '9007199254740993',
    );
    expect(result, isNull);
    expect(adapter.requests, 1);
    if (kIsWeb) expect(adapter.parentId, '9007199254740993');
  });
  for (final adapter in [
    _Adapter(fail: true),
    _Adapter(summaryPayload: '{}'),
  ]) {
    test(
      'failed or malformed summary does not clear cached unread: ${adapter.fail}',
      () async {
        HttpClient.adapterForTest = adapter;
        final repo = _Repo();
        final service = ChannelService.forTest(api: ChannelApi(), repo: repo);
        await service.syncUnreadSummary();
        expect(repo.changes, isEmpty);
      },
    );
  }
  test('valid empty summary clears cached unread', () async {
    HttpClient.adapterForTest = _Adapter(summaryPayload: '{"channels":[]}');
    final repo = _Repo();
    final service = ChannelService.forTest(api: ChannelApi(), repo: repo);
    await service.syncUnreadSummary();
    expect(repo.changes['9007199254740993'], 0);
  });
}
