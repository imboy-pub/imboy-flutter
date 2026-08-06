/// AttachmentApi 纯函数单元测试（presign 直传校验 + 兼容回调形态）
///
/// 测试目标：
/// 1. validateUpload：空/超 100MB/mime 白名单（允许 + 拒绝）
/// 2. compatResp：兼容旧 go-fastdfs 回调形态（data.url 存 object_key）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/attachment_api.dart';

void main() {
  group('AttachmentApi.validateUpload', () {
    test('空文件返回错误', () {
      expect(AttachmentApi.validateUpload(0, 'image/png'), isNotNull);
      expect(AttachmentApi.validateUpload(-1, 'image/png'), isNotNull);
    });

    test('超过 100MB 返回错误', () {
      const int over = 100 * 1024 * 1024 + 1;
      expect(AttachmentApi.validateUpload(over, 'image/png'), isNotNull);
    });

    test('恰好 100MB 通过', () {
      const int exact = 100 * 1024 * 1024;
      expect(AttachmentApi.validateUpload(exact, 'image/png'), isNull);
    });

    test('允许的 mime 通过（image/video/audio/常见文档）', () {
      for (final mime in <String>[
        'image/png',
        'image/jpeg',
        'video/mp4',
        'audio/mp4',
        'application/pdf',
        'application/zip',
        'text/plain',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/octet-stream',
      ]) {
        expect(AttachmentApi.validateUpload(1024, mime), isNull, reason: mime);
      }
    });

    test('mime 大小写不敏感', () {
      expect(AttachmentApi.validateUpload(1024, 'IMAGE/PNG'), isNull);
    });

    test('不在白名单的 mime 被拒绝', () {
      for (final mime in <String>[
        'application/x-msdownload',
        'application/x-sh',
        'font/woff2',
        '',
      ]) {
        expect(
          AttachmentApi.validateUpload(1024, mime),
          isNotNull,
          reason: mime,
        );
      }
    });
  });

  group('AttachmentApi.compatResp', () {
    test('构造兼容旧回调形态，data.url 存 object_key', () {
      final resp = AttachmentApi.compatResp(<String, dynamic>{
        'object_key': 'u1/file_1_a/x.png',
        'size': 2048,
        'file_hash256': 'abc123',
      });
      expect(resp['status'], 'ok');
      final data = resp['data'] as Map<String, dynamic>;
      expect(data['url'], 'u1/file_1_a/x.png');
      expect(data['size'], 2048);
      expect(data['file_hash256'], 'abc123');
    });
  });
}
