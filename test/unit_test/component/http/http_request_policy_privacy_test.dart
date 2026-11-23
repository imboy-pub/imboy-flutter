import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_request_policy.dart';

const _url =
    'https://userinfo_secret:password_secret@synthetic.invalid/resource'
    '?token=query_secret#fragment_secret';
const _authSecret = 'authorization_secret';
const _sourceSecret = 'source_secret';
const _messageSecret = 'message_secret';
const _stackSecret = 'stack_secret';
const _secrets = [
  'userinfo_secret',
  'password_secret',
  'query_secret',
  'fragment_secret',
  _authSecret,
  _sourceSecret,
  _messageSecret,
  _stackSecret,
];

class _MemoryAdapter implements HttpClientAdapter {
  _MemoryAdapter({this.body = '{}', this.errorType});

  final String body;
  final DioExceptionType? errorType;
  DioException? emittedError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (errorType != null) {
      final error = DioException(
        requestOptions: options,
        type: errorType!,
        error: const FormatException('synthetic', _sourceSecret),
        message: _messageSecret,
        stackTrace: StackTrace.fromString(_stackSecret),
      );
      emittedError = error;
      throw error;
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void _expectNoSecrets(List<String> logs) {
  for (final secret in _secrets) {
    expect(logs.join('\n'), isNot(contains(secret)));
  }
}

void main() {
  final root = Uri.parse('https://synthetic.invalid:8443');
  Uri map(String method, String value) =>
      webHumanRequestUri(method, Uri.parse(value), root);

  test(
    'Web current-device revocation is a private POST-only control alias',
    () {
      expect(
        map('POST', '/api/v1/user_device/delete').path,
        '/api/v1/web/user_device/delete',
      );
      expect(
        webHumanPublicPaths,
        isNot(contains('/api/v1/web/user_device/delete')),
      );
      expect(
        () => map('GET', '/api/v1/user_device/delete'),
        throwsFormatException,
      );
      expect(
        () => map('DELETE', '/api/v1/user_device/delete'),
        throwsFormatException,
      );
    },
  );

  test('self region selection is a private loopback-only exact Web POST', () {
    final local = Uri.parse('http://127.0.0.1:9814');
    final route = Uri.parse(webSelfRegionSelectionPath);
    expect(webHumanRequestUri('POST', route, local), local.resolveUri(route));
    expect(webHumanPublicPaths, isNot(contains(webSelfRegionSelectionPath)));
    expect(
      () => webHumanRequestUri('POST', route, root),
      throwsFormatException,
    );
    for (final path in [
      '/api/v1/user/region-selection',
      '/api/v1/user/update',
      '/api/v1/web/user/update',
      '$webSelfRegionSelectionPath?uid=2',
    ]) {
      expect(
        () => webHumanRequestUri('POST', Uri.parse(path), local),
        throwsFormatException,
      );
    }
    for (final path in ['/api/v1/user/update', '/api/v1/web/user/update']) {
      expect(
        () => webHumanRequestUri('PUT', Uri.parse(path), local),
        throwsFormatException,
      );
    }
    for (final verb in ['GET', 'PUT', 'PATCH', 'DELETE']) {
      expect(
        () => webHumanRequestUri(verb, route, local),
        throwsFormatException,
      );
    }
  });

  test('organizations mine is one private exact GET-only Web Human alias', () {
    for (final value in [
      '/api/v1/organizations/mine?page=1&size=10',
      '${root.origin}/api/v1/organizations/mine?page=1&size=10',
      '/api/v1/web/organizations/mine?page=1&size=10',
    ]) {
      final result = map('GET', value);
      expect(result.path, '/api/v1/web/organizations/mine');
      expect(result.queryParameters, {'page': '1', 'size': '10'});
      expect(result.origin, root.origin);
      expect(webHumanRequestUri('GET', result, root), result);
    }
    expect(
      webHumanPublicPaths,
      isNot(contains('/api/v1/web/organizations/mine')),
    );
    for (final method in [
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'HEAD',
      'OPTIONS',
    ]) {
      expect(
        () => map(method, '/api/v1/organizations/mine'),
        throwsFormatException,
      );
      expect(
        () => map(method, '/api/v1/web/organizations/mine'),
        throwsFormatException,
      );
    }
    for (final path in [
      '/api/v1/organizations',
      '/api/v1/organizations/mine/',
      '/api/v1/organizations/1',
      '/api/v1/organizations/mine/members',
      '/api/v1/organizations/invitations/mine',
      '/api/v1/web/organizations',
      '/api/v1/web/organizations/mine/',
      '/api/v1/web/organizations/1',
      '/api/v1/organizations/mine?token=synthetic-secret',
      'https://other.invalid/api/v1/organizations/mine',
    ]) {
      expect(() => map('GET', path), throwsFormatException);
    }
  });

  test('personal history uses only private Web Human alias methods', () {
    const aliases = {
      'status': {'GET'},
      'opt-in': {'POST'},
      'upload': {'POST'},
      'changes': {'GET'},
      'ack-cursor': {'POST'},
      'page': {'GET'},
      'key-package': {'GET', 'POST'},
      'disable': {'POST'},
      'delete-status': {'GET'},
    };
    for (final entry in aliases.entries) {
      final suffix = 'personal-history/${entry.key}';
      final webPath = '/api/v1/web/$suffix';
      expect(webHumanPublicPaths, isNot(contains(webPath)));
      for (final path in ['/api/v1/$suffix', webPath]) {
        for (final method in ['GET', 'POST', 'PUT', 'DELETE']) {
          if (entry.value.contains(method)) {
            expect(map(method, path).path, webPath);
          } else {
            expect(() => map(method, path), throwsFormatException);
          }
        }
      }
    }
    expect(
      () => map('GET', '/api/v1/web/personal-history/changes/'),
      throwsFormatException,
    );
  });

  test('Web Human relative, absolute and alias preserve query exactly', () {
    for (final value in [
      '/api/v1/passport/qr_login/status?session_token=synthetic%2Bcap&x=1&x=2',
      '${root.origin}/api/v1/passport/qr_login/status?session_token=synthetic%2Bcap&x=1&x=2',
      '/api/v1/web/passport/qr_login/status?session_token=synthetic%2Bcap&x=1&x=2',
    ]) {
      final mapped = map('GET', value);
      expect(mapped.origin, root.origin);
      expect(mapped.path, '/api/v1/web/passport/qr_login/status');
      expect(mapped.queryParametersAll, {
        'session_token': ['synthetic+cap'],
        'x': ['1', '2'],
      });
      expect(webHumanRequestUri('GET', mapped, root), mapped);
    }
    expect(map('GET', '/api/v1/init').path, '/api/v1/web/bootstrap');
    expect(map('GET', '/api/v1/app/manifest').path, '/api/v1/app/manifest');
    expect(
      map('POST', '/api/v1/refreshtoken').path,
      '/api/v1/web/refreshtoken',
    );
    expect(map('GET', '/api/v1/msg?action=history_backfill').queryParameters, {
      'action': 'history_backfill',
    });
  });

  test('Web policy allows only exact same-origin GET', () {
    for (final value in [
      '/api/v1/app/policy',
      '${root.origin}/api/v1/app/policy?revision=1',
    ]) {
      final uri = Uri.parse(value);
      expect(map('GET', value), root.resolveUri(uri));
    }
    expect(webHumanPublicPaths, contains('/api/v1/app/policy'));
    for (final method in [
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'HEAD',
      'OPTIONS',
    ]) {
      expect(() => map(method, '/api/v1/app/policy'), throwsFormatException);
    }
    for (final value in [
      'https://other.invalid/api/v1/app/policy',
      'http://synthetic.invalid:8443/api/v1/app/policy',
      'https://synthetic.invalid/api/v1/app/policy',
      '/api/v1/app/policy/',
      '/api/v1/app/policy/extra',
      '/api/v1/web/app/policy',
      '/api/v1/app/policy?token=synthetic-secret',
      '/api/v1/app/policy#fragment',
    ]) {
      expect(() => map('GET', value), throwsFormatException, reason: value);
    }
  });

  test(
    'Web Human finite aliases enforce methods and dynamic read-only paths',
    () {
      const paths = {
        'GET': [
          'msg/offline',
          'msg/history',
          'msg',
          'msg/result',
          'conversation/mine',
          'conversation/pinned',
          'conversation/manual_pending/list',
          'friend/list',
          'user/show',
          'group/page',
          'group/detail',
          'group_member/page',
          'group_notice/page',
          'group/face2face',
          'attachment/direct/status',
          'attachment/view_url',
          'workspaces/mine',
          'workspaces/9007199254740993',
          'workspaces/1/branding',
          'workspaces/1/channels',
          'workspaces/1/groups',
          'channels/subscribed',
          'channels/unread/summary',
          'channel/1',
          'channel/9007199254740993/messages',
          'passport/qr_login/status',
          'passport/qr_login/subscribe',
        ],
        'POST': [
          'passport/login',
          'passport/qr_login/create',
          'passport/qr_login/cancel',
          'msg/offline_ack',
          'conversation/pin',
          'conversation/unpin',
          'conversation/delete',
          'conversation/restore',
          'conversation/manual_pending',
          'friend/add',
          'friend/confirm',
          'user/setting',
          'group/add',
          'group/face2face_save',
          'group_member/join',
          'attachment/direct/register',
          'attachment/direct/declare',
          'attachment/direct/grant',
          'attachment/direct/renew',
          'attachment/direct/finalize',
        ],
      };
      for (final entry in paths.entries) {
        for (final suffix in entry.value) {
          expect(map(entry.key, '/api/v1/$suffix').path, '/api/v1/web/$suffix');
          expect(
            () => map(entry.key == 'GET' ? 'POST' : 'GET', '/api/v1/$suffix'),
            throwsFormatException,
          );
        }
      }
    },
  );

  test(
    'group creation/join family maps to private Web Human aliases (JNY-06)',
    () {
      // UI 建群/受理合同建群与面对面建群的四条写读路径必须出网到 web 别名。
      final aliases = <String, String>{
        'group/add': 'POST',
        'group/face2face': 'GET',
        'group/face2face_save': 'POST',
        'group_member/join': 'POST',
      };
      aliases.forEach((suffix, verb) {
        for (final value in [
          '/api/v1/$suffix',
          '${root.origin}/api/v1/$suffix',
          '/api/v1/web/$suffix',
        ]) {
          final result = map(verb, value);
          expect(result.path, '/api/v1/web/$suffix', reason: value);
          expect(result.origin, root.origin);
          expect(webHumanRequestUri(verb, result, root), result);
        }
        // 逐方法门：错误方法本地即拒（与 backend jwt_methods 一致）
        final wrong = verb == 'POST' ? 'GET' : 'POST';
        expect(
          () => map(wrong, '/api/v1/$suffix'),
          throwsFormatException,
          reason: '$wrong /api/v1/$suffix',
        );
        expect(webHumanPublicPaths, isNot(contains('/api/v1/web/$suffix')));
      });
      // 建群族之外的 group 面（QR/编辑/解散/成员管理写操作）保持拒绝
      for (final value in [
        '/api/v1/group/qrcode',
        '/api/v1/group/edit',
        '/api/v1/group/dissolve',
        '/api/v1/group/set_e2ee_mode',
        '/api/v1/group/add/members',
        '/api/v1/group/add/',
        '/api/v1/group_member/leave',
        '/api/v1/group_member/mute',
        '/api/v1/web/group/qrcode',
      ]) {
        expect(() => map('POST', value), throwsFormatException, reason: value);
        expect(() => map('GET', value), throwsFormatException, reason: value);
      }
    },
  );

  test(
    'Web Human rejects unknown, resource, credential and noncanonical requests',
    () {
      for (final value in [
        'https://other.invalid/api/v1/friend/list',
        'http://synthetic.invalid:8443/api/v1/friend/list',
        'https://user:secret@synthetic.invalid:8443/api/v1/friend/list',
        '//synthetic.invalid:8443/api/v1/friend/list',
        '/api/v1/friend/list#secret',
        '/api/v1/friend/list?tk=secret',
        '/api/v1/friend/list?TOKEN=secret',
        '/api/v1/friend/list?rtk=secret',
        '/api/v1/friend/list?imboy-refreshtoken=secret',
        '/api/v1/friend/list?authorization=secret',
        '/api/v1/msg?action=delete',
        '/api/v1/msg?action=history_backfill&action=delete',
        '/api/v1/friend/delete',
        '/api/v1/attachment/content?token=secret',
        '/resource/file',
        '/api/v1/attachment/presign',
        '/api/v1/web/ws',
        '/api/v1/workspaces/1/members',
        '/api/v1/workspaces/0',
        '/api/v1/channel/1/publish',
        '/api/v1/channel/1/messages/extra',
        '/api/v1/bootstrap',
        '/api/v1/web/init',
        '/api/v1/web/web/friend/list',
        '/api/v1//friend/list',
      ]) {
        expect(() => map('GET', value), throwsFormatException, reason: value);
      }
      expect(() => map('HEAD', '/api/v1/app/manifest'), throwsFormatException);
      expect(
        () => webHumanRequestUri(
          'GET',
          Uri.parse('/api/v1/init'),
          Uri.parse('${root.origin}/prefix'),
        ),
        throwsFormatException,
      );
      try {
        map('GET', '/api/v1/friend/list?token=synthetic-secret');
        fail('Expected rejection');
      } on FormatException catch (error) {
        expect(error.source, isNull);
        expect(error.toString(), isNot(contains('synthetic-secret')));
      }
    },
  );

  test('safeHttpUri strips user info, query values and fragment', () {
    final safe = Uri.parse(safeHttpUri(_url));
    expect(safe.scheme, 'https');
    expect(safe.host, 'synthetic.invalid');
    expect(safe.path, '/resource');
    expect(safe.userInfo, isEmpty);
    expect(safe.queryParameters, {'token': '[REDACTED]'});
    expect(safe.fragment, isEmpty);
    _expectNoSecrets([safe.toString()]);
  });

  test(
    'request and response retain safe logging and normal response',
    () async {
      final logs = <String>[];
      final dio = Dio()
        ..httpClientAdapter = _MemoryAdapter(body: '{"ok":true}')
        ..interceptors.add(SafeHttpLogInterceptor(log: logs.add));
      addTearDown(() => dio.close(force: true));

      final response = await dio.get<dynamic>(
        _url,
        options: Options(headers: {'Authorization': 'Bearer $_authSecret'}),
      );
      final safeUri = safeHttpUri(response.requestOptions.uri);
      expect(response.data, {'ok': true});
      expect(logs, ['HTTP GET $safeUri', 'HTTP 200 $safeUri']);
      _expectNoSecrets(logs);
    },
  );

  test(
    'malformed JSON stays unknown and passes through without source logging',
    () async {
      const body = '{"value":"$_sourceSecret","invalid":}';
      final logs = <String>[];
      DioException? beforeLogger;
      final dio = Dio()
        ..httpClientAdapter = _MemoryAdapter(body: body)
        ..interceptors.add(
          InterceptorsWrapper(
            onError: (error, handler) {
              beforeLogger = error;
              handler.next(error);
            },
          ),
        )
        ..interceptors.add(SafeHttpLogInterceptor(log: logs.add));
      addTearDown(() => dio.close(force: true));

      DioException? caught;
      try {
        await dio.get<dynamic>(
          _url,
          options: Options(
            headers: {'Authorization': 'Bearer $_authSecret'},
            // Keep Dio's JSON parser but make its FormatException source a String.
            responseDecoder: (bytes, _, _) => utf8.decode(bytes),
          ),
        );
        fail('Expected malformed JSON to fail');
      } on DioException catch (error) {
        caught = error;
      }

      expect(caught, same(beforeLogger));
      expect(caught.type, DioExceptionType.unknown);
      expect(caught.error, isA<FormatException>());
      final formatError = caught.error! as FormatException;
      expect(formatError.source, body);
      expect(formatError.toString(), contains(_sourceSecret));
      final safeUri = safeHttpUri(caught.requestOptions.uri);
      expect(logs, ['HTTP GET $safeUri', 'HTTP unknown $safeUri']);
      _expectNoSecrets(logs);
    },
  );

  for (final type in [
    DioExceptionType.unknown,
    DioExceptionType.connectionError,
  ]) {
    test(
      '$type keeps the original exception without logging its details',
      () async {
        final logs = <String>[];
        final adapter = _MemoryAdapter(errorType: type);
        final dio = Dio()
          ..httpClientAdapter = adapter
          ..interceptors.add(SafeHttpLogInterceptor(log: logs.add));
        addTearDown(() => dio.close(force: true));

        DioException? caught;
        try {
          await dio.get<dynamic>(
            _url,
            options: Options(headers: {'Authorization': 'Bearer $_authSecret'}),
          );
          fail('Expected adapter error');
        } on DioException catch (error) {
          caught = error;
        }

        expect(caught, same(adapter.emittedError));
        expect(caught.type, type);
        expect(caught.message, _messageSecret);
        expect((caught.error! as FormatException).source, _sourceSecret);
        expect(caught.stackTrace.toString(), _stackSecret);
        final safeUri = safeHttpUri(caught.requestOptions.uri);
        expect(logs, ['HTTP GET $safeUri', 'HTTP ${type.name} $safeUri']);
        _expectNoSecrets(logs);
      },
    );
  }
}
