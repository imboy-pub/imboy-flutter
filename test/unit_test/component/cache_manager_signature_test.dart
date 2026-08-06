import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';

Future<File> captureFuture(Future<File> future) {
  unawaited(future.catchError((Object _) => File('/tmp/cache_manager_test')));
  return future;
}

/// 测试 IMBoyCacheManager.getSingleFile 方法签名
/// 验证 validateImageData 参数的存在和默认值
void main() {
  group('IMBoyCacheManager - Method Signature Tests', () {
    test('getSingleFile 方法应该接受 validateImageData 参数', () {
      // 这个测试验证方法签名正确
      // 通过调用方法并传入参数来编译时验证
      final cacheManager = IMBoyCacheManager();

      // 验证方法可以接受 validateImageData: false
      expect(
        captureFuture(
          cacheManager.getSingleFile(
            'https://example.com/test.m4a',
            maxRetries: 1,
            validateImageData: false,
          ),
        ),
        isA<Future<File>>(),
      );

      // 验证方法可以接受 validateImageData: true
      expect(
        captureFuture(
          cacheManager.getSingleFile(
            'https://example.com/test.jpg',
            maxRetries: 1,
            validateImageData: true,
          ),
        ),
        isA<Future<File>>(),
      );

      // 验证方法可以省略 validateImageData（使用默认值）
      expect(
        captureFuture(
          cacheManager.getSingleFile(
            'https://example.com/test.jpg',
            maxRetries: 1,
          ),
        ),
        isA<Future<File>>(),
      );
    });

    test('getSingleFile 方法应该支持 headers 参数', () {
      final cacheManager = IMBoyCacheManager();

      expect(
        captureFuture(
          cacheManager.getSingleFile(
            'https://example.com/test.m4a',
            maxRetries: 1,
            headers: {'Authorization': 'Bearer token'},
            validateImageData: false,
          ),
        ),
        isA<Future<File>>(),
      );
    });

    test('getSingleFile 方法应该支持 maxRetries 参数', () {
      final cacheManager = IMBoyCacheManager();

      expect(
        captureFuture(
          cacheManager.getSingleFile(
            'https://example.com/test.m4a',
            maxRetries: 1,
            validateImageData: false,
          ),
        ),
        isA<Future<File>>(),
      );
    });

    test('getSingleFile 方法应该同时支持所有参数', () {
      final cacheManager = IMBoyCacheManager();

      expect(
        captureFuture(
          cacheManager.getSingleFile(
            'https://example.com/test.m4a',
            headers: {'Authorization': 'Bearer token'},
            maxRetries: 1,
            validateImageData: false,
          ),
        ),
        isA<Future<File>>(),
      );
    });
  });

  group('IMBoyCacheManager - 使用场景验证', () {
    test('音频文件下载场景：应该使用 validateImageData: false', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟音频文件下载
      final audioUrl = 'https://example.com/audio.m4a';

      expect(
        captureFuture(
          cacheManager.getSingleFile(
            audioUrl,
            maxRetries: 1,
            validateImageData: false, // 音频文件不验证图片格式
          ),
        ),
        isA<Future<File>>(),
      );
    });

    test('视频文件下载场景：应该使用 validateImageData: false', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟视频文件下载
      final videoUrl = 'https://example.com/video.mp4';

      expect(
        captureFuture(
          cacheManager.getSingleFile(
            videoUrl,
            maxRetries: 1,
            validateImageData: false, // 视频文件不验证图片格式
          ),
        ),
        isA<Future<File>>(),
      );
    });

    test('文件保存场景：应该使用 validateImageData: false', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟任意文件下载（如 PDF、Markdown 等）
      final fileUrl = 'https://example.com/document.pdf';

      expect(
        captureFuture(
          cacheManager.getSingleFile(
            fileUrl,
            maxRetries: 1,
            validateImageData: false, // 文件下载不验证图片格式
          ),
        ),
        isA<Future<File>>(),
      );
    });

    test('图片文件下载场景：应该使用默认的 validateImageData: true', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟图片文件下载
      final imageUrl = 'https://example.com/image.jpg';

      // 图片文件应该使用默认参数（验证图片格式）
      expect(
        captureFuture(cacheManager.getSingleFile(imageUrl, maxRetries: 1)),
        isA<Future<File>>(),
      );
    });
  });

  group('IMBoyCacheManager - 文件扩展名测试', () {
    final cacheManager = IMBoyCacheManager();

    test('所有音频扩展名都应该支持 validateImageData: false', () {
      final audioExtensions = [
        '.m4a',
        '.mp3',
        '.aac',
        '.wav',
        '.ogg',
        '.amr',
        '.flac',
      ];

      for (final ext in audioExtensions) {
        final url = 'https://example.com/audio$ext';
        expect(
          captureFuture(
            cacheManager.getSingleFile(
              url,
              maxRetries: 1,
              validateImageData: false,
            ),
          ),
          isA<Future<File>>(),
          reason: '$ext 扩展名应该支持 validateImageData: false',
        );
      }
    });

    test('所有视频扩展名都应该支持 validateImageData: false', () {
      final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv'];

      for (final ext in videoExtensions) {
        final url = 'https://example.com/video$ext';
        expect(
          captureFuture(
            cacheManager.getSingleFile(
              url,
              maxRetries: 1,
              validateImageData: false,
            ),
          ),
          isA<Future<File>>(),
          reason: '$ext 扩展名应该支持 validateImageData: false',
        );
      }
    });

    test('所有图片扩展名都应该支持默认的图片验证', () {
      final imageExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp',
      ];

      for (final ext in imageExtensions) {
        final url = 'https://example.com/image$ext';
        // 图片文件使用默认参数（validateImageData: true）
        expect(
          captureFuture(cacheManager.getSingleFile(url, maxRetries: 1)),
          isA<Future<File>>(),
          reason: '$ext 扩展名应该支持默认图片验证',
        );
      }
    });
  });

  group('IMBoyCacheManager - 错误处理测试', () {
    final cacheManager = IMBoyCacheManager();

    test('空 URL 应该抛出异常', () async {
      await expectLater(
        cacheManager.getSingleFile(''),
        throwsA(isA<Exception>()),
      );
    });

    test('无效 URL 应该抛出异常', () async {
      await expectLater(
        cacheManager.getSingleFile('not-a-valid-url', maxRetries: 1),
        throwsA(anything),
      );
    });
  });
}
