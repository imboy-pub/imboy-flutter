import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_interceptor.dart';

void main() {
  group('isPublicStorageRequest', () {
    test('公开存储 host 命中 → true（不应注入 JWT）', () {
      expect(
        isPublicStorageRequest(
          Uri.parse('https://s3.imboy.pub/u3/avatar/20260620/x.jpg'),
          'https://s3.imboy.pub',
        ),
        isTrue,
      );
    });

    test('presigned 私有读同 host（带 X-Amz 查询）→ true', () {
      expect(
        isPublicStorageRequest(
          Uri.parse(
            'https://s3.imboy.pub/imboy/u3/file/x.jpg?X-Amz-Signature=abc',
          ),
          'https://s3.imboy.pub',
        ),
        isTrue,
      );
    });

    test('业务 API host → false（仍需注入 JWT）', () {
      expect(
        isPublicStorageRequest(
          Uri.parse('https://pro.imboy.pub/api/v1/attachment/confirm'),
          'https://s3.imboy.pub',
        ),
        isFalse,
      );
    });

    test('base 带末尾斜杠仍按 host 匹配', () {
      expect(
        isPublicStorageRequest(
          Uri.parse('https://s3.imboy.pub/u3/avatar/x.jpg'),
          'https://s3.imboy.pub/',
        ),
        isTrue,
      );
    });

    test('base 为空 → false（不误伤业务请求）', () {
      expect(
        isPublicStorageRequest(Uri.parse('https://pro.imboy.pub/api/v1/x'), ''),
        isFalse,
      );
    });
  });

  group('isPresignedRequest（故障B 回归：presigned 非公开 host 也须跳过 JWT）', () {
    test('presigned 在 S3 API 端点 host（本地 LAN IP:3900）→ true', () {
      // 真机本地链路 endpoint=http://192.168.1.112:3900，host≠publicBaseUrl，
      // 旧逻辑只看 isPublicStorageRequest=false → 注入 authorization → nginx 误路由 400。
      final uri = Uri.parse(
        'http://192.168.1.112:3900/imboy/u3/c2c/20260625/file_x/d8u7.jpg'
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc123',
      );
      expect(isPresignedRequest(uri), isTrue);
      // 证明旧的 host 判断漏掉了它（正是本次 bug）。
      expect(isPublicStorageRequest(uri, 'https://s3.imboy.pub'), isFalse);
    });

    test('普通业务 API 请求（无 X-Amz 签名）→ false（仍注入 JWT）', () {
      final uri = Uri.parse('https://pro.imboy.pub/api/v1/attachment/view_url');
      expect(isPresignedRequest(uri), isFalse);
    });
  });
}
