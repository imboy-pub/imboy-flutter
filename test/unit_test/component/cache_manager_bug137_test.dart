import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/service/asset_url_resolver.dart';

/// BUG#137 回归：Garage 私桶完整 URL（群文件等）下载必须提取 object_key
/// （剥掉 bucket 段）走后端 view_url 签发 presign GET，而不是拼 go-fastdfs
/// HMAC（?s&a&v，Garage 不认 → 404）。
void main() {
  group('IMBoyCacheManager - BUG#137 Garage 完整 URL', () {
    test('s3.imboy.pub 完整 URL 提取 object_key 并走 presign', () async {
      String? capturedKey;
      AssetUrlResolver.instance.fetcherOverride = (objectKey) {
        capturedKey = objectKey;
        // 返回一个必然下载失败的 URL，验证「提取 + 签发」发生即可
        return Future<String>.value(
          'https://presigned-bug137.invalid/file_123_abc/a.mp4?X-Amz-Signature=x',
        );
      };
      addTearDown(() => AssetUrlResolver.instance.fetcherOverride = null);

      await expectLater(
        IMBoyCacheManager().getSingleFile(
          // bucket 段 = imboy，object_key = file_123_abc/a.mp4
          'https://s3.imboy.pub/imboy/file_123_abc/a.mp4',
          validateImageData: false,
        ),
        throwsA(anything), // 下载必然失败（presigned-bug137.invalid 不可达）
      );
      expect(capturedKey, 'file_123_abc/a.mp4');
    });

    test('非 Garage host 完整 URL 不劫持到 presign（保持 viewUrl 语义）', () async {
      // host 非 publicBaseUrl → 走原 viewUrl 路径，不应触发 fetcherOverride
      var fetcherCalled = false;
      AssetUrlResolver.instance.fetcherOverride = (objectKey) {
        fetcherCalled = true;
        return Future<String>.value(objectKey);
      };
      addTearDown(() => AssetUrlResolver.instance.fetcherOverride = null);

      await expectLater(
        IMBoyCacheManager().getSingleFile(
          // 历史 go-fastdfs / 外部 host：仍走 viewUrlAsync（本地拼 HMAC 后
          // 下载失败），不经过 AssetUrlResolver
          'https://fastdfs.example.com/group1/M00/00/00/a.mp4',
          validateImageData: false,
        ),
        throwsA(anything),
      );
      expect(fetcherCalled, isFalse);
    });
  });
}
