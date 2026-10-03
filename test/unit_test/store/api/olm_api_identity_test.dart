/// C17b 复审 gap 收口：`OlmApi.getIdentity` 的 HTTP 接线测试。
///
/// getIdentity 必须把服务端可控的响应体交给 `parseIdentityPayload`
/// 严格解析（fail-closed 前缀异常），而不是旧的
/// `Map<String, dynamic>.from(payload)` 弱检查——后者遇非 String key
/// 抛 TypeError、遇字段类型混淆静默放行给消费点硬 cast
/// （`_lookupPeerIdentity` 的 `as String`），以非契约异常炸进建会话路径。
///
/// 此处在 HTTP 层注入损坏 payload，验证接线真实生效（parse 层的
/// oracle 契约由 parser_fuzz_harness_test.dart 覆盖）。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/olm_api.dart';

class _RecordingOlmApi extends OlmApi {
  final List<Map<String, dynamic>> getCalls = <Map<String, dynamic>>[];

  IMBoyHttpResponse getResponse = IMBoyHttpResponse.success(
    const <String, dynamic>{},
  );

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    getCalls.add(<String, dynamic>{
      'uri': uri,
      'queryParameters': queryParameters,
    });
    return getResponse;
  }
}

const Map<String, dynamic> kValidIdentity = <String, dynamic>{
  'device_id': 'dev-peer-1',
  'ed25519_key': 'AA',
  'curve25519_key': 'AA',
  'signature': 'AA',
};

void main() {
  group('OlmApi.getIdentity（C17b gap 接线）', () {
    test('命中 get_identity endpoint 并透传 uid/device_id', () async {
      final api = _RecordingOlmApi()
        ..getResponse = IMBoyHttpResponse.success(kValidIdentity);

      final r = await api.getIdentity(uid: '100', deviceId: 'dev-peer-1');

      expect(api.getCalls.single['uri'], API.olmGetIdentity);
      expect(api.getCalls.single['queryParameters'], {
        'uid': '100',
        'device_id': 'dev-peer-1',
      });
      expect(r['device_id'], 'dev-peer-1');
    });

    test('合法 payload 原样返回（四契约字段）', () async {
      final api = _RecordingOlmApi()
        ..getResponse = IMBoyHttpResponse.success(kValidIdentity);

      final r = await api.getIdentity(uid: '100', deviceId: 'dev-peer-1');
      expect(r.keys.toSet(), {
        'device_id',
        'ed25519_key',
        'curve25519_key',
        'signature',
      });
    });

    test('HTTP 失败保持既有空 map 语义（上层验签层 fail-closed）', () async {
      final api = _RecordingOlmApi()
        ..getResponse = IMBoyHttpResponse.failure(errMsg: 'not_found');

      final r = await api.getIdentity(uid: '100', deviceId: 'dev-x');
      expect(r, isEmpty);
    });

    test('损坏 payload：fail-closed 前缀异常，而非 TypeError', () async {
      final vectors = <dynamic>[
        'not a map',
        42,
        true,
        null,
        <dynamic>[],
        {...kValidIdentity, 'curve25519_key': 32},
        {...kValidIdentity, 'curve25519_key': null},
        {...kValidIdentity, 'ed25519_key': <dynamic>[]},
        {...kValidIdentity}..remove('signature'),
        {...kValidIdentity}..remove('device_id'),
        // 非 String key：旧实现的 Map<String, dynamic>.from 在此抛
        // TypeError（C17b 复审 gap 与 m2 同型崩溃面）。
        <dynamic, dynamic>{...kValidIdentity, 7: 'x'},
      ];
      for (var i = 0; i < vectors.length; i++) {
        final api = _RecordingOlmApi()
          ..getResponse = IMBoyHttpResponse.success(vectors[i]);
        await expectLater(
          api.getIdentity(uid: '100', deviceId: 'dev-peer-1'),
          throwsA(
            predicate<Object>(
              (e) =>
                  e is! TypeError &&
                  e.toString().contains('olm get_identity: invalid payload'),
              '必须是 fail-closed 前缀异常',
            ),
          ),
          reason: 'vector #$i 不得以 TypeError 泄漏或静默返回',
        );
      }
    });
  });
}
