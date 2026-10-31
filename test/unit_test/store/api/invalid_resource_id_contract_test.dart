import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RawAdapter implements HttpClientAdapter {
  _RawAdapter(this.body);

  final String body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _channelEnvelope(String id) =>
    '''
{"code":0,"msg":"success","payload":{"list":[
  {"id":42,"name":"valid first","creator_uid":7},
  {"id":$id,"name":"second","creator_uid":9007199254740993,
   "subscriber_count":9007199254740993,"price":9007199254740993,
   "created_at":1700000000123,"updated_at":1700000000456,
   "custom_id":"9007199254740993","message_id":"d2s4h7krvim0abcdefg0"}
],"has_more":false,"next_cursor":""}}
''';

String _groupEnvelope(String key, String id) =>
    '''
{"code":0,"msg":"success","payload":{"workspace_id":100,"list":[
  {"id":42,"title":"valid first","scope":"workspace","workspace_id":100},
  {"$key":$id,"title":"second","scope":"workspace","workspace_id":100,
   "owner_uid":9007199254740993,"creator_uid":9007199254740995,
   "member_count":9007199254740993,"price":9007199254740993,
   "created_at":1700000000123,"updated_at":1700000000456,
   "message_id":"d2s4h7krvim0abcdefg0"}
]}}
''';

void _expectRequest(_RawAdapter adapter, String path) {
  expect(adapter.requests, hasLength(1));
  expect(adapter.requests.single.path, path);
  expect(adapter.requests.single.responseDecoder, isNotNull);
}

void _captureResponse(HttpClient api, void Function(dynamic) capture) {
  api.dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        capture(response.data);
        handler.next(response);
      },
    ),
  );
}

Matcher _invalidId(String resource, String field) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    'invalid $resource id field: $field',
  ),
);

void _expectDecodedRows(dynamic decoded, String idKey, Object? secondId) {
  final rows = decoded['payload']['list'] as List;
  expect(rows[0]['id'], '42');
  expect(rows[1][idKey], secondId);
}

String _listEnvelope(String rows) =>
    '{"code":0,"msg":"success","payload":{"workspace_id":100,'
    '"list":[$rows],"has_more":false,"next_cursor":""}}';

Future<List<dynamic>> _personalGroups(GroupApi api, bool cursor) async {
  if (cursor) return (await api.pageCursor(attr: 'join')).list;
  final payload = await api.page(attr: 'join');
  expect(payload, isNotNull, reason: 'a valid response must not become null');
  return payload!['list'] as List;
}

String _listPath(String endpoint) => switch (endpoint) {
  'subscribed page' || 'subscribed cursor' => '/api/v1/channels/subscribed',
  'managed' => '/api/v1/channels/managed',
  'search' => '/api/v1/channels/search',
  'discover' => '/api/v1/channels/discover',
  _ => '/api/v1/workspaces/100/groups',
};

Future<List<Object>> _loadList(String endpoint, HttpClient api) async {
  if (api is WorkspaceApi) return api.groups('100');
  final channels = api as ChannelApi;
  return switch (endpoint) {
    'subscribed page' => (await channels.getSubscribedChannelsPage()).list,
    'subscribed cursor' =>
      (await channels.getSubscribedChannelsCursorPage()).list,
    'managed' => await channels.getManagedChannels(),
    'search' => await channels.searchChannels('synthetic'),
    'discover' => await channels.discoverChannels(),
    _ => throw StateError('unknown endpoint: $endpoint'),
  };
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
  });

  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  for (final endpoint in [
    'subscribed page',
    'subscribed cursor',
    'managed',
    'search',
    'discover',
    'workspace groups',
  ]) {
    for (final invalid in ['null', '42']) {
      for (final mixed in [false, true]) {
        test(
          '$endpoint rejects ${mixed ? 'mixed' : 'single'} $invalid row',
          () async {
            final rows = mixed ? '{"id":123,"name":"valid"},$invalid' : invalid;
            final adapter = _RawAdapter(_listEnvelope(rows));
            HttpClient.adapterForTest = adapter;
            final HttpClient api = endpoint == 'workspace groups'
                ? WorkspaceApi()
                : ChannelApi();
            dynamic decoded;
            _captureResponse(api, (value) => decoded = value);
            await expectLater(
              _loadList(endpoint, api),
              throwsA(
                isA<FormatException>().having(
                  (error) => error.message,
                  'message',
                  endpoint == 'workspace groups'
                      ? 'invalid group list row'
                      : 'invalid channel list row',
                ),
              ),
            );
            _expectRequest(adapter, _listPath(endpoint));
            expect(decoded['payload']['list'], hasLength(mixed ? 2 : 1));
          },
        );
      }
    }
    test('$endpoint accepts a valid empty list', () async {
      final adapter = _RawAdapter(_listEnvelope(''));
      HttpClient.adapterForTest = adapter;
      final HttpClient api = endpoint == 'workspace groups'
          ? WorkspaceApi()
          : ChannelApi();
      expect(await _loadList(endpoint, api), isEmpty);
      _expectRequest(adapter, _listPath(endpoint));
    });
  }

  for (final testCase in [
    ('"group_id":111,"id":111,"gid":111', '111'),
    ('"group_id":null,"id":222,"gid":222', '222'),
    ('"group_id":null,"id":null,"gid":333', '333'),
  ]) {
    test('workspace group alias priority ${testCase.$1}', () async {
      final adapter = _RawAdapter(_listEnvelope('{${testCase.$1}}'));
      HttpClient.adapterForTest = adapter;
      final groups = await WorkspaceApi().groups('100');
      _expectRequest(adapter, '/api/v1/workspaces/100/groups');
      expect(groups.single.groupId, testCase.$2);
    });
  }

  for (final testCase in [
    ('"group_id":111,"id":0,"gid":111', 'id'),
    ('"group_id":111,"id":111,"gid":0', 'gid'),
    ('"group_id":0,"id":111,"gid":111', 'group_id'),
  ]) {
    test(
      'workspace group rejects invalid populated alias ${testCase.$2}',
      () async {
        final adapter = _RawAdapter(_listEnvelope('{${testCase.$1}}'));
        HttpClient.adapterForTest = adapter;
        await expectLater(
          WorkspaceApi().groups('100'),
          _invalidId('group', testCase.$2),
        );
        _expectRequest(adapter, '/api/v1/workspaces/100/groups');
      },
    );
  }

  for (final endpoint in ['workspace', 'page', 'cursor']) {
    for (final aliases in [
      '"group_id":111,"id":222',
      '"group_id":111,"gid":222',
      '"id":111,"gid":222',
      '"group_id":9007199254740993,"id":"9007199254740995"',
    ]) {
      test(
        '$endpoint rejects conflicting aliases $aliases without partial list',
        () async {
          final adapter = _RawAdapter(_listEnvelope('{"id":42},{$aliases}'));
          HttpClient.adapterForTest = adapter;
          final HttpClient api = endpoint == 'workspace'
              ? WorkspaceApi()
              : GroupApi();
          dynamic decoded;
          _captureResponse(api, (value) => decoded = value);
          final request = api is WorkspaceApi
              ? api.groups('100')
              : _personalGroups(api as GroupApi, endpoint == 'cursor');
          await expectLater(
            request,
            throwsA(
              isA<FormatException>().having(
                (error) => error.message,
                'message',
                'conflicting group id fields',
              ),
            ),
          );
          _expectRequest(
            adapter,
            endpoint == 'workspace'
                ? '/api/v1/workspaces/100/groups'
                : '/api/v1/group/page',
          );
          expect(decoded['payload']['list'], hasLength(2));
        },
      );
    }

    for (final aliases in [
      '"group_id":111,"id":"111","gid":111',
      '"group_id":9007199254740993,"id":"9007199254740993","gid":9007199254740993',
    ]) {
      test(
        '$endpoint accepts equal numeric and string aliases $aliases',
        () async {
          final adapter = _RawAdapter(_listEnvelope('{"id":42},{$aliases}'));
          HttpClient.adapterForTest = adapter;
          final HttpClient api = endpoint == 'workspace'
              ? WorkspaceApi()
              : GroupApi();
          dynamic decoded;
          _captureResponse(api, (value) => decoded = value);
          final expected = aliases.contains('9007199254740993')
              ? '9007199254740993'
              : '111';
          if (api is WorkspaceApi) {
            final rows = await api.groups('100');
            expect(rows.map((row) => row.groupId), ['42', expected]);
          } else {
            final rows = await _personalGroups(
              api as GroupApi,
              endpoint == 'cursor',
            );
            expect(rows, hasLength(2));
            expect(rows.last['group_id'], expected);
            expect(rows.last['id'], expected);
            expect(rows.last['gid'], expected);
          }
          _expectRequest(
            adapter,
            endpoint == 'workspace'
                ? '/api/v1/workspaces/100/groups'
                : '/api/v1/group/page',
          );
          _expectDecodedRows(decoded, 'group_id', expected);
        },
      );
    }
  }

  // Both JSON number tokens and JSON strings occur on the wire. The oversized
  // number must be supplied as raw JSON, not encoded from a rounded Dart value.
  const invalidIds = <String, String>{
    'negative number': '-1',
    'negative string': '"-1"',
    'zero number': '0',
    'zero string': '"0"',
    'fraction number': '12.5',
    'fraction string': '"12.5"',
    'above bigint number': '9223372036854775808',
    'above bigint string': '"9223372036854775808"',
    'non-numeric string': '"not-an-id"',
  };

  for (final cursor in [false, true]) {
    final name = cursor ? 'personal groups cursor' : 'personal groups page';
    for (final entry in invalidIds.entries) {
      for (final key in ['id', 'group_id', 'gid']) {
        test(
          '$name rejects $key ${entry.key} without returning partial rows',
          () async {
            final adapter = _RawAdapter(_groupEnvelope(key, entry.value));
            HttpClient.adapterForTest = adapter;
            final api = GroupApi();
            dynamic decoded;
            _captureResponse(api, (value) => decoded = value);
            await expectLater(
              _personalGroups(api, cursor),
              _invalidId('group', key),
            );
            _expectRequest(adapter, '/api/v1/group/page');
            expect(decoded['payload']['list'], hasLength(2));
          },
        );
      }
    }
    for (final invalid in ['null', '42']) {
      for (final mixed in [false, true]) {
        test(
          '$name rejects ${mixed ? 'mixed' : 'single'} $invalid row',
          () async {
            final rows = mixed
                ? '{"id":123,"title":"valid"},$invalid'
                : invalid;
            final adapter = _RawAdapter(_listEnvelope(rows));
            HttpClient.adapterForTest = adapter;
            final api = GroupApi();
            dynamic decoded;
            _captureResponse(api, (value) => decoded = value);
            await expectLater(
              _personalGroups(api, cursor),
              throwsA(
                isA<FormatException>().having(
                  (error) => error.message,
                  'message',
                  'invalid group list row',
                ),
              ),
            );
            _expectRequest(adapter, '/api/v1/group/page');
            expect(decoded['payload']['list'], hasLength(mixed ? 2 : 1));
          },
        );
      }
    }
    test('$name accepts valid empty list', () async {
      final adapter = _RawAdapter(_listEnvelope(''));
      HttpClient.adapterForTest = adapter;
      expect(await _personalGroups(GroupApi(), cursor), isEmpty);
      _expectRequest(adapter, '/api/v1/group/page');
    });
    for (final key in ['id', 'group_id', 'gid']) {
      test('$name returns exact BIGINT $key from raw JSON', () async {
        final adapter = _RawAdapter(_groupEnvelope(key, '9223372036854775807'));
        HttpClient.adapterForTest = adapter;
        final api = GroupApi();
        dynamic decoded;
        _captureResponse(api, (value) => decoded = value);
        final rows = await _personalGroups(api, cursor);
        _expectRequest(adapter, '/api/v1/group/page');
        _expectDecodedRows(decoded, key, '9223372036854775807');
        expect(rows, hasLength(2));
        expect(rows.last[key], '9223372036854775807');
      });
    }
  }

  for (final entry in invalidIds.entries) {
    for (final endpoint in [
      'subscribed page',
      'subscribed cursor',
      'discover',
    ]) {
      test('$endpoint rejects ${entry.key} without returning a list', () async {
        final adapter = _RawAdapter(_channelEnvelope(entry.value));
        HttpClient.adapterForTest = adapter;
        final api = ChannelApi();
        dynamic decoded;
        _captureResponse(api, (value) => decoded = value);
        final request = switch (endpoint) {
          'subscribed page' => api.getSubscribedChannelsPage(),
          'subscribed cursor' => api.getSubscribedChannelsCursorPage(),
          _ => api.discoverChannels(),
        };
        await expectLater(request, _invalidId('channel', 'id'));
        _expectRequest(
          adapter,
          endpoint == 'discover'
              ? '/api/v1/channels/discover'
              : '/api/v1/channels/subscribed',
        );
        expect(decoded['payload']['list'], hasLength(2));
      });
    }

    // GroupModel supports all three aliases; reject each instead of producing 0.
    for (final key in ['id', 'group_id', 'gid']) {
      test('workspace groups rejects $key ${entry.key}', () async {
        final adapter = _RawAdapter(_groupEnvelope(key, entry.value));
        HttpClient.adapterForTest = adapter;
        final api = WorkspaceApi();
        dynamic decoded;
        _captureResponse(api, (value) => decoded = value);
        await expectLater(api.groups('100'), _invalidId('group', key));
        _expectRequest(adapter, '/api/v1/workspaces/100/groups');
        expect(decoded['payload']['list'], hasLength(2));
      });
    }
  }

  test('subscribed list keeps valid 64-bit IDs and non-ID data', () async {
    final body = _channelEnvelope('9223372036854775807');
    final adapter = _RawAdapter(body);
    HttpClient.adapterForTest = adapter;
    final api = ChannelApi();
    dynamic decoded;
    _captureResponse(api, (value) => decoded = value);

    final page = await api.getSubscribedChannelsPage();
    _expectRequest(adapter, '/api/v1/channels/subscribed');
    expect(page.list.map((channel) => channel.id), [
      '42',
      '9223372036854775807',
    ]);
    final channel = page.list.last;
    expect(channel.creatorId, '9007199254740993');
    expect(channel.createdAt.millisecondsSinceEpoch, 1700000000123);
    expect(channel.updatedAt.millisecondsSinceEpoch, 1700000000456);
    expect(channel.customId, '9007199254740993');

    _expectDecodedRows(decoded, 'id', '9223372036854775807');
    final row = decoded['payload']['list'][1] as Map;
    final original = (jsonDecode(body) as Map)['payload']['list'][1] as Map;
    expect(row['creator_uid'], '9007199254740993');
    expect(row['subscriber_count'], original['subscriber_count']);
    expect(row['price'], original['price']);
    expect(channel.subscriberCount, original['subscriber_count']);
    expect(channel.price, original['price']);
    expect(row['created_at'], 1700000000123);
    expect(row['message_id'], 'd2s4h7krvim0abcdefg0');
  });

  for (final endpoint in ['subscribed cursor', 'discover']) {
    test('$endpoint keeps exact valid IDs through its decoder', () async {
      final adapter = _RawAdapter(_channelEnvelope('9223372036854775807'));
      HttpClient.adapterForTest = adapter;
      final api = ChannelApi();
      dynamic decoded;
      _captureResponse(api, (value) => decoded = value);
      final List<ChannelModel> channels;
      if (endpoint == 'discover') {
        channels = await api.discoverChannels();
      } else {
        final page = await api.getSubscribedChannelsCursorPage();
        channels = page.list;
        expect(page.hasMore, isFalse);
        expect(page.nextCursor, isNull);
      }
      _expectRequest(
        adapter,
        endpoint == 'discover'
            ? '/api/v1/channels/discover'
            : '/api/v1/channels/subscribed',
      );
      _expectDecodedRows(decoded, 'id', '9223372036854775807');
      expect(channels.map((channel) => channel.id), [
        '42',
        '9223372036854775807',
      ]);
      expect(channels.last.creatorId, '9007199254740993');
    });
  }

  for (final key in ['group_id', 'gid']) {
    test('workspace groups accepts exact valid $key', () async {
      final adapter = _RawAdapter(_groupEnvelope(key, '9223372036854775807'));
      HttpClient.adapterForTest = adapter;
      final api = WorkspaceApi();
      dynamic decoded;
      _captureResponse(api, (value) => decoded = value);
      final groups = await api.groups('100');
      _expectRequest(adapter, '/api/v1/workspaces/100/groups');
      _expectDecodedRows(decoded, key, '9223372036854775807');
      expect(groups.map((group) => group.groupId), [
        '42',
        '9223372036854775807',
      ]);
    });
  }

  test('workspace groups keeps valid 64-bit IDs and non-ID data', () async {
    final body = _groupEnvelope('id', '9223372036854775807');
    final adapter = _RawAdapter(body);
    HttpClient.adapterForTest = adapter;
    final api = WorkspaceApi();
    dynamic decoded;
    _captureResponse(api, (value) => decoded = value);

    final groups = await api.groups('100');
    _expectRequest(adapter, '/api/v1/workspaces/100/groups');
    expect(groups.map((group) => group.groupId), ['42', '9223372036854775807']);
    final group = groups.last;
    expect(group.ownerUid, '9007199254740993');
    expect(group.creatorUid, '9007199254740995');
    expect(group.createdAt, 1700000000123);
    expect(group.updatedAt, 1700000000456);

    _expectDecodedRows(decoded, 'id', '9223372036854775807');
    final row = decoded['payload']['list'][1] as Map;
    final original = (jsonDecode(body) as Map)['payload']['list'][1] as Map;
    expect(row['owner_uid'], '9007199254740993');
    expect(row['creator_uid'], '9007199254740995');
    expect(row['member_count'], original['member_count']);
    expect(row['price'], original['price']);
    expect(group.memberCount, original['member_count']);
    expect(row['created_at'], 1700000000123);
    expect(row['message_id'], 'd2s4h7krvim0abcdefg0');
  });
}
