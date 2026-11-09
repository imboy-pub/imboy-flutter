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

  // AT05 NC-1 / F01 App 腿：elib_oss 100MiB 边界三值（104857599/104857600/104857601）。
  // 后端合同（imboy lib/elib_oss.erl ?MAX_FILE_SIZE = 104857600，含端放行）：
  //   UNDER 104857599 → 接受；EXACT 104857600 → 接受；OVER 104857601 → 拒绝。
  // App 端以 AttachmentApi.maxUploadBytes 为唯一判定源（三入口共享，见源码注释
  // 「direct-v1 复用同一校验源」），此处以字节字面量钉死合同，防止常量漂移。
  group('AttachmentApi.validateUpload - 100MiB 边界三值（elib_oss 对齐）', () {
    test('上限常量钉死为 104857600（与后端 ?MAX_FILE_SIZE 同值）', () {
      expect(AttachmentApi.maxUploadBytes, 104857600);
      expect(AttachmentApi.maxUploadBytes, 100 * 1024 * 1024);
    });

    test('104857599（UNDER，上限-1）通过', () {
      expect(AttachmentApi.validateUpload(104857599, 'image/png'), isNull);
      expect(
        AttachmentApi.validateUpload(
          AttachmentApi.maxUploadBytes - 1,
          'image/png',
        ),
        isNull,
      );
    });

    test('104857600（EXACT，恰好上限）通过——判定为 > 而非 >=（含端放行）', () {
      expect(AttachmentApi.validateUpload(104857600, 'image/png'), isNull);
      expect(
        AttachmentApi.validateUpload(AttachmentApi.maxUploadBytes, 'image/png'),
        isNull,
      );
    });

    test('104857601（OVER，上限+1）拒绝，错误消息指明超限', () {
      final String? err = AttachmentApi.validateUpload(104857601, 'image/png');
      expect(err, isNotNull);
      expect(err, contains('文件超过上限'));
      expect(err, contains('100MB'));
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
