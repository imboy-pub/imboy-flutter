/// AssetsService.isObjectKey / viewUrl 双模分流测试
///
/// 测试目标（S1 历史消息零回归核心保证）：
/// 1. legacy go-fastdfs 完整 URL → isObjectKey=false，viewUrl 走旧 HMAC 授权分支
/// 2. Garage presign object_key → isObjectKey=true，viewUrl 原样透传（不污染）
/// 3. 边界：空串、def_avatar、相对路径、含 scheme 的非法串
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/assets.dart';

void main() {
  group('AssetsService.isObjectKey', () {
    test('Garage object_key 形态返回 true', () {
      expect(
        AssetsService.isObjectKey(
          'u123/file_1717000000_a1b2c3d4e5f6a7b8/x.png',
        ),
        isTrue,
      );
      expect(AssetsService.isObjectKey('u1/file_0_0/a.jpg'), isTrue);
    });

    test('legacy go-fastdfs 完整 URL 返回 false（走旧链路，历史消息零回归）', () {
      expect(
        AssetsService.isObjectKey('https://fs.imboy.pub/group1/default/a.png'),
        isFalse,
      );
      expect(
        AssetsService.isObjectKey('http://127.0.0.1:8080/upload/x.jpg?v=1&a=b'),
        isFalse,
      );
    });

    test('边界用例返回 false', () {
      expect(AssetsService.isObjectKey(''), isFalse);
      // 不以 u<digits>/ 开头
      expect(AssetsService.isObjectKey('avatar/def_avatar.png'), isFalse);
      expect(AssetsService.isObjectKey('user123/file_x/a.png'), isFalse);
      // 含 scheme 一律按完整 URL 处理
      expect(AssetsService.isObjectKey('s3://u1/file_x/a.png'), isFalse);
    });
  });

  group('AssetsService.viewUrl 双模', () {
    test('object_key 原样透传（toString 还原为 object_key 本身）', () {
      const key = 'u123/file_1717000000_a1b2c3d4e5f6a7b8/x.png';
      final uri = AssetsService.viewUrl(key);
      expect(uri.toString(), key);
      // 不应被追加 v/a/s 授权参数
      expect(uri.queryParameters.containsKey('a'), isFalse);
      expect(uri.queryParameters.containsKey('s'), isFalse);
    });

    test('legacy 完整 URL 仍追加授权参数（旧行为不变）', () {
      final uri = AssetsService.viewUrl('https://fs.imboy.pub/g1/a.png');
      expect(uri.scheme, 'https');
      expect(uri.host, 'fs.imboy.pub');
      // 旧链路应带上 HMAC 授权参数 v/a/s
      expect(uri.queryParameters.containsKey('v'), isTrue);
    });
  });
}
