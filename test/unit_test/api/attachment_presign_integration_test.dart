/// 附件 presign 直传 —— 真实后端集成测试
///
/// 从 Dart 侧对运行中的 imboy 后端 + Garage 跑完整链路：
///   presign → PUT 直传 → confirm 落库 → view_url 签发 → 读回校验 → 反向 403
///
/// 仅连接显式授权的本地合成后端与存储；凭证从环境变量读取。
/// 设置 IMBOY_TEST_TOKEN、IMBOY_API_BASE 和 TEST_ALLOW_API_WRITES=true 后运行：
///   flutter test test/unit_test/api/attachment_presign_integration_test.dart
/// 本目录的 flutter_test_config 恢复真实网络；缺凭证或写授权时跳过。
/// 对象由隔离存储的运行器在退出时回收，不可连接已有业务库或存储。
library;

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'api_test_client.dart';

final String _token = Platform.environment['IMBOY_TEST_TOKEN'] ?? '';
final String _apiBase =
    Platform.environment['IMBOY_API_BASE'] ?? 'http://127.0.0.1:9800';

void main() {
  final enabled = _token.isNotEmpty && ApiTestConfig.allowBusinessWrites;

  test('附件集成测试拒绝外部地址和带用户信息的地址', () {
    for (final url in [
      'https://pro.imboy.pub/assets',
      'http://10.0.0.1/assets',
      'http://synthetic@127.0.0.1/assets',
      'file:///tmp/assets',
    ]) {
      expect(() => ensureLocalAttachmentTarget(url), throwsStateError);
    }
  });

  test('附件集成测试的本地请求仍需显式写入授权', () {
    for (final url in ['http://127.0.0.1:9800', 'https://localhost:9800']) {
      if (ApiTestConfig.allowBusinessWrites) {
        expect(() => ensureLocalAttachmentTarget(url), returnsNormally);
      } else {
        expect(() => ensureLocalAttachmentTarget(url), throwsStateError);
      }
    }
  });

  group('附件 presign 真实后端集成', () {
    late ApiTestClient client;
    late Dio storage;

    setUp(() {
      ensureLocalAttachmentTarget(_apiBase);
      if (ApiTestConfig.isNetworkMocked) {
        throw StateError('附件集成测试的真实网络未启用');
      }
      storage = Dio(
        BaseOptions(
          followRedirects: false,
          validateStatus: (status) => status != null,
        ),
      );
      client = ApiTestClient(baseUrl: _apiBase, accessToken: _token);
    });

    tearDown(() {
      client.close();
      storage.close(force: true);
    });

    test('presign → PUT → confirm → view_url → 读回一致 → 反向 403', () async {
      // 1. presign
      final preBody = await client.get(
        '/api/v1/attachment/presign',
        expectedStatusCode: 200,
        queryParameters: <String, dynamic>{
          'filename': 'it_test.png',
          'mime_type': 'image/png',
        },
      );
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
      ensureLocalAttachmentTarget(putUrl);
      final put = await storage.put<dynamic>(
        putUrl,
        data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        options: Options(
          contentType: 'image/png',
          headers: <String, dynamic>{Headers.contentLengthHeader: bytes.length},
        ),
      );
      expect(put.statusCode, anyOf(200, 204), reason: 'PUT 直传应成功');

      // 3. confirm 落库
      final confirmBody = await client.post(
        '/api/v1/attachment/confirm',
        data: <String, dynamic>{
          'object_key': objectKey,
          'md5': 'integration-md5',
          'mime_type': 'image/png',
          'size': bytes.length,
        },
      );
      expect(confirmBody['code'], 0, reason: 'confirm 应落库成功');

      // 4. view_url 签发
      final viewBody = await client.get(
        '/api/v1/attachment/view_url',
        queryParameters: <String, dynamic>{'object_key': objectKey},
      );
      expect(viewBody['code'], 0);
      final String signedUrl =
          (viewBody['payload'] as Map<String, dynamic>)['url'] as String;
      expect(signedUrl, contains('X-Amz-Signature'));

      // 5. 读回内容一致
      ensureLocalAttachmentTarget(signedUrl);
      storage.options.responseType = ResponseType.bytes;
      final got = await storage.get<List<int>>(signedUrl);
      expect(got.statusCode, 200);
      expect(Uint8List.fromList(got.data!), bytes, reason: '读回字节应与上传一致');

      // 6. 反向：去掉签名的直链应 403（公开读已关闭）
      final bare = signedUrl.split('?').first;
      final bareResp = await storage.get<List<int>>(bare);
      expect(
        bareResp.statusCode,
        anyOf(401, 403),
        reason: '无签名直链应被拒绝（bucket 未开公开读）',
      );
    });
  }, skip: enabled ? false : '需 IMBOY_TEST_TOKEN 和 TEST_ALLOW_API_WRITES=true');
}

/// 限制真实写入与签发链接都只连接本地运行器，避免响应诱导外部访问。
void ensureLocalAttachmentTarget(String url) {
  ApiTestConfig.ensureBusinessWriteAllowed(
    path: '/api/v1/attachment',
    baseUrl: url,
  );
  final target = Uri.tryParse(url);
  if (target == null ||
      !{'http', 'https'}.contains(target.scheme) ||
      !{'127.0.0.1', 'localhost'}.contains(target.host) ||
      target.userInfo.isNotEmpty) {
    throw StateError('附件集成测试仅允许本地隔离后端与存储');
  }
}
