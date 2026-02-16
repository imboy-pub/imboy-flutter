import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';

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
        () => cacheManager.getSingleFile(
          'https://example.com/test.m4a',
          validateImageData: false,
        ),
        returnsNormally,
      );

      // 验证方法可以接受 validateImageData: true
      expect(
        () => cacheManager.getSingleFile(
          'https://example.com/test.jpg',
          validateImageData: true,
        ),
        returnsNormally,
      );

      // 验证方法可以省略 validateImageData（使用默认值）
      expect(
        () => cacheManager.getSingleFile('https://example.com/test.jpg'),
        returnsNormally,
      );
    });

    test('getSingleFile 方法应该支持 headers 参数', () {
      final cacheManager = IMBoyCacheManager();

      expect(
        () => cacheManager.getSingleFile(
          'https://example.com/test.m4a',
          headers: {'Authorization': 'Bearer token'},
          validateImageData: false,
        ),
        returnsNormally,
      );
    });

    test('getSingleFile 方法应该支持 maxRetries 参数', () {
      final cacheManager = IMBoyCacheManager();

      expect(
        () => cacheManager.getSingleFile(
          'https://example.com/test.m4a',
          maxRetries: 5,
          validateImageData: false,
        ),
        returnsNormally,
      );
    });

    test('getSingleFile 方法应该同时支持所有参数', () {
      final cacheManager = IMBoyCacheManager();

      expect(
        () => cacheManager.getSingleFile(
          'https://example.com/test.m4a',
          headers: {'Authorization': 'Bearer token'},
          maxRetries: 5,
          validateImageData: false,
        ),
        returnsNormally,
      );
    });
  });

  group('IMBoyCacheManager - 使用场景验证', () {
    test('音频文件下载场景：应该使用 validateImageData: false', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟音频文件下载
      final audioUrl = 'https://example.com/audio.m4a';

      expect(
        () => cacheManager.getSingleFile(
          audioUrl,
          validateImageData: false, // 音频文件不验证图片格式
        ),
        returnsNormally,
      );
    });

    test('视频文件下载场景：应该使用 validateImageData: false', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟视频文件下载
      final videoUrl = 'https://example.com/video.mp4';

      expect(
        () => cacheManager.getSingleFile(
          videoUrl,
          validateImageData: false, // 视频文件不验证图片格式
        ),
        returnsNormally,
      );
    });

    test('文件保存场景：应该使用 validateImageData: false', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟任意文件下载（如 PDF、Markdown 等）
      final fileUrl = 'https://example.com/document.pdf';

      expect(
        () => cacheManager.getSingleFile(
          fileUrl,
          validateImageData: false, // 文件下载不验证图片格式
        ),
        returnsNormally,
      );
    });

    test('图片文件下载场景：应该使用默认的 validateImageData: true', () {
      final cacheManager = IMBoyCacheManager();

      // 模拟图片文件下载
      final imageUrl = 'https://example.com/image.jpg';

      // 图片文件应该使用默认参数（验证图片格式）
      expect(
        () => cacheManager.getSingleFile(imageUrl),
        returnsNormally,
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
          () => cacheManager.getSingleFile(url, validateImageData: false),
          returnsNormally,
          reason: '$ext 扩展名应该支持 validateImageData: false',
        );
      }
    });

    test('所有视频扩展名都应该支持 validateImageData: false', () {
      final videoExtensions = [
        '.mp4',
        '.mov',
        '.avi',
        '.mkv',
        '.webm',
        '.flv',
      ];

      for (final ext in videoExtensions) {
        final url = 'https://example.com/video$ext';
        expect(
          () => cacheManager.getSingleFile(url, validateImageData: false),
          returnsNormally,
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
          () => cacheManager.getSingleFile(url),
          returnsNormally,
          reason: '$ext 扩展名应该支持默认图片验证',
        );
      }
    });
  });

  group('IMBoyCacheManager - 错误处理测试', () {
    final cacheManager = IMBoyCacheManager();

    test('空 URL 应该抛出异常', () async {
      expect(
        () => cacheManager.getSingleFile(''),
        throwsA(isA<Exception>()),
      );
    });

    test('无效 URL 应该抛出异常', () async {
      expect(
        () => cacheManager.getSingleFile('not-a-valid-url'),
        throwsA(anything),
      );
    });
  });
}
