/// EPGZ-06 W3 — OA SSO API 响应解析与错误映射测试
///
/// 覆盖 [parseOaSsoIssueResponse] / [oaSsoIssueFailureFromCode] 纯函数
/// 矩阵（A5 冻结合同：成功 payload 三字段、错误整数信封 400/401/403/
/// 404/5xx、网络异常归一），以及 [OaSsoApi.issueCode] 经
/// [HttpClient.adapterForTest] 的真实请求形状（POST 路径 + body 三字段，
/// 不含任何 secret 字段）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_sso_api.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_sso_issue.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/modules/enterprise_oa/presentation/oa_tab_page.dart';
import 'package:imboy/service/storage.dart';

/// 记录请求 + 恒返指定响应的出口（不触网；镜像 A7 push_token_lifecycle 基建）。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  int statusCode;
  dynamic body;

  /// 每次请求的 (method, path, data)。
  final List<(String, String, Object?)> requests = [];
  final List<String> wireBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((options.method, options.uri.path, options.data));
    if (requestStream != null) {
      final bytes = await requestStream.expand((chunk) => chunk).toList();
      wireBodies.add(utf8.decode(bytes));
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': payload,
};

/// 构造失败响应（整数信封 = HTTP status；镜像 A5 human 面错误信封）。
IMBoyHttpResponse failedResp(int code) {
  return IMBoyHttpResponse.failure(errCode: code, errMsg: 'err $code');
}

void main() {
  group('parseOaSsoIssueResponse — 成功路径', () {
    test('200 + 三字段 payload → OaSsoCodeIssued', () {
      // 真实管线中 DefaultHttpTransformer 已剥信封：resp.payload 即内层。
      final resp = IMBoyHttpResponse.success(<String, dynamic>{
        'code': 'oa_sso_${'a' * 43}',
        'expires_in': 60,
        'redirect_uri': 'https://oa.example.com/landing',
      });
      final result = parseOaSsoIssueResponse(
        resp,
        fallbackRedirectUri: 'https://oa.example.com/landing',
      );
      expect(result, isA<OaSsoCodeIssued>());
      final issued = result as OaSsoCodeIssued;
      expect(issued.code, startsWith('oa_sso_'));
      expect(issued.expiresInSeconds, 60);
      expect(issued.redirectUri, 'https://oa.example.com/landing');
    });

    test('expires_in 缺失回退合同恒值 60；redirect 回显缺失回退请求值', () {
      final resp = IMBoyHttpResponse.success(<String, dynamic>{
        'code': 'oa_sso_x',
      });
      final issued = parseOaSsoIssueResponse(
        resp,
        fallbackRedirectUri: 'https://oa.example.com/fallback',
      ) as OaSsoCodeIssued;
      expect(issued.expiresInSeconds, oaSsoCodeExpiresInSeconds);
      expect(issued.redirectUri, 'https://oa.example.com/fallback');
    });

    test('200 但 payload 缺 code → server 类别（服务端违约）', () {
      final resp = IMBoyHttpResponse.success(<String, dynamic>{});
      final result = parseOaSsoIssueResponse(
        resp,
        fallbackRedirectUri: 'https://oa.example.com/landing',
      );
      expect((result as OaSsoIssueFailed).kind, OaSsoIssueFailureKind.server);
    });
  });

  group('oaSsoIssueFailureFromCode — A5 错误码矩阵', () {
    test('400 → badRequest（字段语法 / redirect 未注册）', () {
      final kind = oaSsoIssueFailureFromCode(failedResp(400));
      expect(kind, OaSsoIssueFailureKind.badRequest);
    });

    test('401 → unauthorized（无/坏 Human JWT）', () {
      expect(
        oaSsoIssueFailureFromCode(failedResp(401)),
        OaSsoIssueFailureKind.unauthorized,
      );
    });

    test('403 → forbidden（非 active 成员 / 无 active mapping）', () {
      expect(
        oaSsoIssueFailureFromCode(failedResp(403)),
        OaSsoIssueFailureKind.forbidden,
      );
    });

    test('404 → notFound（key 不可解析/app 停用/org 非 active/多义）', () {
      expect(
        oaSsoIssueFailureFromCode(failedResp(404)),
        OaSsoIssueFailureKind.notFound,
      );
    });

    test('500/502/503/504 → server', () {
      for (final code in [500, 502, 503, 504]) {
        expect(
          oaSsoIssueFailureFromCode(failedResp(code)),
          OaSsoIssueFailureKind.server,
          reason: '$code',
        );
      }
    });

    test('未知码 → unknown', () {
      expect(
        oaSsoIssueFailureFromCode(failedResp(418)),
        OaSsoIssueFailureKind.unknown,
      );
    });
  });

  group('OaSsoApi.issueCode — 真实请求形状（adapter 捕获）', () {
    // _setDefaultConfig 需要 StorageService/SecureStorage 就绪 + 非过期
    // JWT（镜像 A7 push_token_lifecycle_test 的环境准备）。
    String fakeJwt() {
      String b64(String s) =>
          base64Url.encode(utf8.encode(s)).replaceAll('=', '');
      return '${b64('{"alg":"HS256","typ":"JWT"}')}.'
          '${b64('{"exp":9999999999}')}.${b64('test-signature')}';
    }

    Future<void> prepareEnv(_RecordingAdapter adapter) async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      // 铁律：adapterForTest 只在 HttpClient 构造时绑定——先设 adapter
      // 再构造 OaSsoApi()。
      HttpClient.adapterForTest = adapter;
      addTearDown(() => HttpClient.adapterForTest = null);
      FlutterSecureStorage.setMockInitialValues({
        'secure_token': fakeJwt(),
        'secure_refresh_token': fakeJwt(),
      });
    }

    test('生产 launcher 将企业 ID 无损编码为 JSON integer', () async {
      final adapter = _RecordingAdapter(
        200,
        okEnvelope(
          payload: {
            'code': 'oa_sso_issued',
            'expires_in': 60,
            'redirect_uri': 'https://oa.example.com/landing',
          },
        ),
      );
      await prepareEnv(adapter);
      final result =
          await ApiOaSsoIssueLauncher(organizationId: '9223372036854775807')
              .launch(
                applicationKey: 'ak_gz_customer_01',
                redirectUri: 'https://oa.example.com/landing',
                nonce: 'nonce-0123456789abcdef',
              );
      expect(result, isA<OaSsoCodeIssued>());
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.wireBodies.single,
        contains('"organization_id":9223372036854775807,'),
      );
      expect(
        adapter.wireBodies.single,
        contains('"nonce":"nonce-0123456789abcdef"'),
      );
    });

    test('非法企业 ID 在网络请求前拒绝', () async {
      final adapter = _RecordingAdapter(200, okEnvelope());
      await prepareEnv(adapter);
      final api = OaSsoApi();
      for (final id in [
        '',
        '0',
        '-1',
        '01',
        '1.0',
        '9223372036854775808',
        '1,"x":2',
      ]) {
        final result = await api.issueCode(
          applicationKey: 'ak_gz_customer_01',
          redirectUri: 'https://oa.example.com/landing',
          nonce: 'nonce-0123456789abcdef',
          organizationId: id,
        );
        expect(
          (result as OaSsoIssueFailed).kind,
          OaSsoIssueFailureKind.badRequest,
        );
      }
      expect(adapter.requests, isEmpty);
    });

    test('POST /api/v1/oa/sso/code，body 仅三字段且无 secret', () async {
      final adapter = _RecordingAdapter(
        200,
        okEnvelope(
          payload: <String, dynamic>{
            'code': 'oa_sso_issued',
            'expires_in': 60,
            'redirect_uri': 'https://oa.example.com/landing',
          },
        ),
      );
      await prepareEnv(adapter);

      final result = await OaSsoApi().issueCode(
        applicationKey: 'ak_gz_customer_01',
        redirectUri: 'https://oa.example.com/landing',
        nonce: 'nonce-0123456789abcdef',
      );

      expect(adapter.requests, hasLength(1));
      final (method, path, data) = adapter.requests.single;
      expect(method, 'POST');
      expect(path, '/api/v1/oa/sso/code');
      final body = data as Map<String, dynamic>;
      expect(body.keys.toSet(), <String>{
        'application_key',
        'redirect_uri',
        'nonce',
      });
      expect(body['application_key'], 'ak_gz_customer_01');
      expect(body['nonce'], 'nonce-0123456789abcdef');
      // 合同：payload 明文 code 只在本响应出现一次。
      expect((result as OaSsoCodeIssued).code, 'oa_sso_issued');
    });

    test('404 信封 → notFound → 状态机目标 error（映射链贯通）', () async {
      final adapter = _RecordingAdapter(404, <String, dynamic>{
        'code': 404,
        'msg': 'resource not found',
      });
      await prepareEnv(adapter);

      final result = await OaSsoApi().issueCode(
        applicationKey: 'ak_unknown',
        redirectUri: 'https://oa.example.com/landing',
        nonce: 'nonce-0123456789abcdef',
      );
      final kind = (result as OaSsoIssueFailed).kind;
      expect(kind, OaSsoIssueFailureKind.notFound);
      expect(targetStatusForIssueFailure(kind), OaTabStatus.error);
    });
  });
}
