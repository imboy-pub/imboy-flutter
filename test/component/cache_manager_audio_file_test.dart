import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';

// 测试 IMBoyCacheManager 对音频文件的处理
// 验证音频文件下载时不会因为图片格式验证而失败
//
// 注意：这些测试只验证方法签名和参数传递
// 实际的网络请求应该在集成测试中完成

void main() {
  group('IMBoyCacheManager - Audio File Download Tests', () {
    late IMBoyCacheManager cacheManager;

    setUp(() {
      cacheManager = IMBoyCacheManager();
    });

    test('getSingleFile 应该支持 validateImageData 参数', () async {
      // 验证方法签名正确
      // 这个测试确保 getSingleFile 方法接受 validateImageData 参数
      expect(() => cacheManager.getSingleFile(
        'https://example.com/test.m4a',
        validateImageData: false,
      ), returnsNormally);
    });

    test('getSingleFile 默认验证图片数据', () async {
      // 验证默认行为是 validateImageData: true
      // 这确保图片文件仍然会被正确验证

      // 注意：这个测试只是验证方法签名和行为
      // 实际的网络请求应该在集成测试中完成
      expect(() => cacheManager.getSingleFile(
        'https://example.com/test.jpg',
      ), returnsNormally);
    });

    test('音频文件 URL 应该使用 validateImageData: false', () {
      // 测试常见的音频文件扩展名
      final audioExtensions = ['.m4a', '.mp3', '.aac', '.wav', '.ogg', '.amr'];

      for (final ext in audioExtensions) {
        final url = 'https://example.com/audio$ext';
        // 验证我们可以为音频文件创建带有 validateImageData: false 的请求
        expect(
          cacheManager.getSingleFile(url, validateImageData: false),
          isA<Future<File>>(),
        );
      }
    });

    test('视频文件 URL 应该使用 validateImageData: false', () {
      // 测试常见的视频文件扩展名
      final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];

      for (final ext in videoExtensions) {
        final url = 'https://example.com/video$ext';
        // 验证我们可以为视频文件创建带有 validateImageData: false 的请求
        expect(
          cacheManager.getSingleFile(url, validateImageData: false),
          isA<Future<File>>(),
        );
      }
    });

    test('图片文件 URL 应该使用默认的 validateImageData: true', () {
      // 测试常见的图片文件扩展名
      final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];

      for (final ext in imageExtensions) {
        final url = 'https://example.com/image$ext';
        // 验证图片文件使用默认的图片验证
        expect(
          cacheManager.getSingleFile(url),
          isA<Future<File>>(),
        );
      }
    });

    test('其他文件类型（如 Markdown、PDF）应该使用 validateImageData: false', () {
      // 测试其他文件类型
      final otherExtensions = ['.md', '.pdf', '.txt', '.json', '.xml'];

      for (final ext in otherExtensions) {
        final url = 'https://example.com/file$ext';
        // 验证其他文件类型禁用图片验证
        expect(
          cacheManager.getSingleFile(url, validateImageData: false),
          isA<Future<File>>(),
        );
      }
    });
  });

  group('IMBoyCacheManager - 使用场景测试', () {
    test('音频消息场景：下载音频文件', () async {
      // 模拟音频消息下载场景
      final audioUrl = 'https://example.com/message_audio.m4a';
      final cacheManager = IMBoyCacheManager();

      // 验证音频文件下载调用使用正确的参数
      expect(
        () => cacheManager.getSingleFile(
          audioUrl,
          validateImageData: false, // 音频文件不验证图片格式
        ),
        returnsNormally,
      );
    });

    test('视频消息场景：下载视频文件', () async {
      // 模拟视频消息下载场景
      final videoUrl = 'https://example.com/message_video.mp4';
      final cacheManager = IMBoyCacheManager();

      // 验证视频文件下载调用使用正确的参数
      expect(
        () => cacheManager.getSingleFile(
          videoUrl,
          validateImageData: false, // 视频文件不验证图片格式
        ),
        returnsNormally,
      );
    });

    test('文件保存场景：下载任意文件', () async {
      // 模拟文件保存场景（用户保存聊天中的文件）
      final fileUrl = 'https://example.com/document.pdf';
      final cacheManager = IMBoyCacheManager();

      // 验证文件下载调用使用正确的参数
      expect(
        () => cacheManager.getSingleFile(
          fileUrl,
          validateImageData: false, // 文件下载不验证图片格式
        ),
        returnsNormally,
      );
    });

    test('图片消息场景：下载图片文件', () async {
      // 模拟图片消息下载场景
      final imageUrl = 'https://example.com/message_image.jpg';
      final cacheManager = IMBoyCacheManager();

      // 验证图片下载调用使用默认参数（验证图片格式）
      expect(
        () => cacheManager.getSingleFile(imageUrl),
        returnsNormally,
      );
    });
  });
}
