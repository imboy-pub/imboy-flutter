import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/component/http/http_exceptions.dart' as failures;
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/run.dart' show appProviderContainer;

import 'negative_ui.dart';
import 'negative_phase.dart';

class NegativeAccess {
  NegativeAccess() {
    _observer = InterceptorsWrapper(
      onResponse: (response, handler) {
        _record(response.requestOptions, response.statusCode, response.data);
        handler.next(response);
      },
      onError: (error, handler) {
        _record(
          error.requestOptions,
          error.response?.statusCode,
          error.response?.data,
        );
        handler.next(error);
      },
    );
    _attach(HttpClient.client.dio);
  }

  late final InterceptorsWrapper _observer;
  ChannelApi? _channelApi;
  final List<Dio> _observedClients = [];
  final List<({String method, String path, int status, int code})> records = [];
  Set<String> get _paths => {
    API.msgHistory,
    API.groupMemberPage,
    API.groupDetail,
    API.msgOffline,
    '/api/v1/channel/$negativeChannelId/discussion',
    '/api/v1/channel/$negativeChannelId/discussion/join',
  };

  void _record(RequestOptions options, int? status, dynamic data) {
    final path = options.uri.path;
    if (!_paths.contains(path)) return;
    final code = data is Map && data['code'] is int ? data['code'] as int : -1;
    records.add((
      method: options.method,
      path: path,
      status: status ?? 0,
      code: code,
    ));
  }

  void bindChannelClient() {
    if (_channelApi != null) throw StateError('channel observer already bound');
    final api = appProviderContainer.read(channelApiProvider);
    _attach(HttpClient.client.dio);
    _attach(api.dio);
    _channelApi = api;
  }

  void _attach(Dio client) {
    if (_observedClients.any((existing) => identical(existing, client))) return;
    client.interceptors.add(_observer);
    _observedClients.add(client);
  }

  void close() {
    for (final client in _observedClients) {
      client.interceptors.remove(_observer);
    }
  }

  Future<void> beforeAccess() async {
    expect((await _history()).code, 0);
    expect((await _members()).code, 0);
    expect((await _detail()).code, 0);
  }

  Future<void> denyAccess() async {
    await _denied(_history, API.msgHistory, 403);
    await _denied(_members, API.groupMemberPage, 1);
    await _denied(_detail, API.groupDetail, 403);
  }

  Future<void> _denied(
    Future<IMBoyHttpResponse> Function() call,
    String path,
    int expectedCode,
  ) async {
    final start = records.length;
    final response = await call();
    expect(response.ok, isFalse);
    expect(
      response.code,
      expectedCode,
      reason: 'real membership refusal required',
    );
    final observed = records.skip(start).where((r) => r.path == path).toList();
    expect(observed, isNotEmpty, reason: 'actual HTTP response required');
    expect(observed.last.code, expectedCode);
    expect(observed.last.status, anyOf(200, 403));
  }

  Future<IMBoyHttpResponse> _history() => HttpClient.client.get(
    API.msgHistory,
    queryParameters: {
      'chat_type': 'c2g',
      'peer_id': negativeGroupId,
      'after_seq': 0,
      'limit': 50,
    },
  );

  Future<IMBoyHttpResponse> _members() => HttpClient.client.get(
    API.groupMemberPage,
    queryParameters: {'gid': negativeGroupId, 'page': 1, 'size': 10},
  );

  Future<IMBoyHttpResponse> _detail() => HttpClient.client.get(
    API.groupDetail,
    queryParameters: {'gid': negativeGroupId},
  );

  int get joinResponses =>
      records.where((r) => r.path.endsWith('/discussion/join')).length;

  int get bindingResponses =>
      records.where((r) => r.path.endsWith('/discussion')).length;

  void expectJoinDeniedSince(int prior) {
    final joins = records
        .where((r) => r.path.endsWith('/discussion/join'))
        .toList();
    expect(
      joins.length,
      greaterThan(prior),
      reason: 'real stale-cache join request required',
    );
    expect(joins.last.code, 403);
    expect(joins.last.status, anyOf(200, 403));
  }

  Future<void> waitBindingDenied(NegativeUi ui, int prior) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      await negativePump(ui.tester);
      if (bindingResponses > prior) break;
    }
    final bindings = records
        .where((r) => r.path.endsWith('/discussion'))
        .toList();
    expect(bindings.length, greaterThan(prior));
    expect(bindings.last.method, 'GET');
    expect(bindings.last.code, 403);
    expect(bindings.last.status, anyOf(200, 403));
  }

  Future<void> joinDeniedWithoutUi() async {
    final prior = joinResponses;
    try {
      final api = _channelApi;
      if (api == null) throw StateError('production channel client not bound');
      await api.joinDiscussion(negativeChannelId);
      fail('old session unexpectedly joined revoked discussion');
    } on failures.HttpException catch (error) {
      expect(error.code, 403);
    }
    expectJoinDeniedSince(prior);
  }

  Future<void> offlineDenied(String id) async {
    final response = await HttpClient.client.get(API.msgOffline);
    expect(response.code, 0);
    final payload = IMBoyHttpResponse.payloadAsMap(response.payload);
    expect(payload['c2g'], isA<Map<String, dynamic>>());
    final c2g = Map<String, dynamic>.from(payload['c2g'] as Map);
    expect(c2g['total'], 0);
    expect(c2g['list'], isA<List<dynamic>>());
    expect(
      (c2g['list'] as List).where(
        (item) =>
            item is Map && (item['msg_id'] ?? item['id']).toString() == id,
      ),
      isEmpty,
    );
  }

  static Future<bool> httpReachable() async {
    final base = Uri.parse(
      const String.fromEnvironment('API_BASE_URL_OVERRIDE'),
    );
    if (base.scheme != 'http' ||
        base.host != '127.0.0.1' ||
        base.userInfo.isNotEmpty) {
      throw StateError('owned transport probe requires explicit loopback');
    }
    final client = io.HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(base.replace(path: API.appFeatures))
          .timeout(const Duration(seconds: 6));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      expect(response.statusCode, 200);
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 6))) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) throw StateError('transport probe oversized');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      expect(decoded is Map && decoded['code'] == 0, isTrue);
      return true;
    } on io.SocketException {
      return false;
    } on TimeoutException {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
