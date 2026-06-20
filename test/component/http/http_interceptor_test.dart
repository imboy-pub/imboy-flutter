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
          Uri.parse('https://pro.imboy.pub/v1/attachment/confirm'),
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
        isPublicStorageRequest(Uri.parse('https://pro.imboy.pub/v1/x'), ''),
        isFalse,
      );
    });
  });
}
