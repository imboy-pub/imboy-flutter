/// 附件 presign 直传 —— 真实后端集成测试
///
/// 从 Dart 侧对运行中的 imboy 后端 + Garage 跑完整链路：
///   presign → PUT 直传 → confirm 落库 → view_url 签发 → 读回校验 → 反向 403
///
/// 运行（需后端 9800 + Garage 就绪 + 有效 JWT）：
///   后端生成 token：`token_ds:encrypt_token(Uid)`
///   flutter test test/integration/attachment_presign_integration_test.dart \
///     --dart-define=IMBOY_TEST_TOKEN=<token> \
///     --dart-define=IMBOY_API_BASE=http://127.0.0.1:9800
///
/// 未提供 token 时整组 skip（不阻塞无后端的 CI）。
library;

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:dio/dio.dart';
// 纯 Dart 测试（package:test）：用 `dart test` 运行以发起真实网络请求；
// 勿用 `flutter test`（其测试绑定会拦截 HTTP 返回 400）。
import 'package:test/test.dart';

final String _token = Platform.environment['IMBOY_TEST_TOKEN'] ?? '';
final String _apiBase =
    Platform.environment['IMBOY_API_BASE'] ?? 'http://127.0.0.1:9800';

void main() {
  final bool hasToken = _token.isNotEmpty;

  group(
    '附件 presign 真实后端集成',
    () {
      late Dio dio;

      setUp(() {
        dio = Dio(
          BaseOptions(
            baseUrl: _apiBase,
            // 后端鉴权头无 Bearer 前缀（见 attach_handler 验证）
            headers: <String, dynamic>{'Authorization': _token},
            validateStatus: (s) => s != null,
          ),
        );
      });

      test('presign → PUT → confirm → view_url → 读回一致 → 反向 403', () async {
        // 1. presign
        final pre = await dio.get<dynamic>(
          '/api/v1/attachment/presign',
          queryParameters: <String, dynamic>{
            'filename': 'it_test.png',
            'mime_type': 'image/png',
          },
        );
        expect(pre.statusCode, 200);
        final preBody = pre.data is String
            ? json.decode(pre.data as String) as Map<String, dynamic>
            : pre.data as Map<String, dynamic>;
        expect(preBody['code'], 0);
        final payload = preBody['payload'] as Map<String, dynamic>;
        final String putUrl = payload['put_url'] as String;
        final String objectKey = payload['object_key'] as String;
        expect(putUrl, isNotEmpty);
        expect(
          RegExp(r'^u\d+/').hasMatch(objectKey),
          isTrue,
          reason: 'object_key 应绑定 uid 前缀: $objectKey',
        );

        // 2. PUT 直传 Garage（裸请求，不带 JWT）
        final Uint8List bytes = Uint8List.fromList(
          utf8.encode(
            'imboy-presign-integration-${DateTime.now().toIso8601String()}',
          ),
        );
        final putDio = Dio(BaseOptions(validateStatus: (s) => s != null));
        final put = await putDio.put<dynamic>(
          putUrl,
          data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
          options: Options(
            contentType: 'image/png',
            headers: <String, dynamic>{
              Headers.contentLengthHeader: bytes.length,
            },
          ),
        );
        expect(put.statusCode, anyOf(200, 204), reason: 'PUT 直传应成功');

        // 3. confirm 落库
        final confirm = await dio.post<dynamic>(
          '/api/v1/attachment/confirm',
          data: <String, dynamic>{
            'object_key': objectKey,
            'md5': 'integration-md5',
            'mime_type': 'image/png',
            'size': bytes.length,
          },
        );
        final confirmBody = confirm.data is String
            ? json.decode(confirm.data as String) as Map<String, dynamic>
            : confirm.data as Map<String, dynamic>;
        expect(confirmBody['code'], 0, reason: 'confirm 应落库成功');

        // 4. view_url 签发
        final view = await dio.get<dynamic>(
          '/api/v1/attachment/view_url',
          queryParameters: <String, dynamic>{'object_key': objectKey},
        );
        final viewBody = view.data is String
            ? json.decode(view.data as String) as Map<String, dynamic>
            : view.data as Map<String, dynamic>;
        expect(viewBody['code'], 0);
        final String signedUrl =
            (viewBody['payload'] as Map<String, dynamic>)['url'] as String;
        expect(signedUrl, contains('X-Amz-Signature'));

        // 5. 读回内容一致
        final getDio = Dio(
          BaseOptions(
            responseType: ResponseType.bytes,
            validateStatus: (s) => s != null,
          ),
        );
        final got = await getDio.get<List<int>>(signedUrl);
        expect(got.statusCode, 200);
        expect(Uint8List.fromList(got.data!), bytes, reason: '读回字节应与上传一致');

        // 6. 反向：去掉签名的直链应 403（公开读已关闭）
        final bare = signedUrl.split('?').first;
        final bareResp = await getDio.get<List<int>>(bare);
        expect(
          bareResp.statusCode,
          anyOf(401, 403),
          reason: '无签名直链应被拒绝（bucket 未开公开读）',
        );
      });
    },
    skip: hasToken ? false : '需 --dart-define=IMBOY_TEST_TOKEN（后端+Garage 就绪）',
  );
}
