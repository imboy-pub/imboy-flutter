import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/service/user_profile_service.dart';

/// UserProfileService.updateField 单元测试
///
/// 统一 PersonalInfoPage 与 ProfilePage 重复的「PUT 更新字段 + 同步本地缓存」逻辑，
/// 消除 DRY 漂移。通过可选回调注入隔离 HttpClient / UserRepoLocal 单例依赖。
void main() {
  group('Web settings own projection', () {
    for (final value in [false, 0, 'false', '0', 'no', 'off', ' FALSE ']) {
      test('legacy explicit visibility false remains false: $value', () {
        final parsed = UserProfileService.parseWebSettings({
          'allow_search': 2,
          'enable_visibility_read': value,
          'visibility_read_fraction': '0.83',
          'visibility_read_delay_ms': '1350',
          'font_size': 'huge',
          'manual_pending': 'must-not-copy',
        });
        expect(parsed['allow_search'], isFalse);
        expect(parsed['enable_visibility_read'], isFalse);
        expect(parsed['visibility_read_fraction'], .83);
        expect(parsed['visibility_read_delay_ms'], 1350);
        expect(parsed['font_size'], 'huge');
        expect(parsed.length, 5);
      });
    }
    test('complete empty setting keeps existing model defaults', () {
      final parsed = UserProfileService.parseWebSettings(<String, dynamic>{});
      expect(parsed['enable_visibility_read'], isTrue);
      expect(parsed['font_size'], 'normal');
    });
    for (final bad in [
      null,
      {'enable_visibility_read': 'garbage'},
      {'allow_search': <Object?>[]},
      {'visibility_read_fraction': 'oops'},
      {'font_size': 'extra_large'},
    ]) {
      test('known bad settings never silently fall back: $bad', () {
        expect(
          () => UserProfileService.parseWebSettings(bad),
          throwsFormatException,
        );
      });
    }
  });
  group('UserProfileService.updateField', () {
    test('成功时返回 true，并以 {field,value} 发起 PUT', () async {
      Map<String, dynamic>? sentData;
      Map<String, dynamic>? savedPayload;

      final ok = await UserProfileService.updateField(
        'avatar',
        'u123/file_x/a.png',
        httpPut: (data) async {
          sentData = data;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readCurrent: () => <String, dynamic>{'avatar': 'old', 'nickname': 'n'},
        saveLocal: (p) => savedPayload = p,
      );

      expect(ok, isTrue);
      expect(sentData, {'field': 'avatar', 'value': 'u123/file_x/a.png'});
      // 顶层字段写入本地 payload
      expect(savedPayload!['avatar'], 'u123/file_x/a.png');
      expect(savedPayload!['nickname'], 'n');
    });

    test('PUT 失败时返回 false，且不写本地缓存', () async {
      var savedCalled = false;

      final ok = await UserProfileService.updateField(
        'avatar',
        'u123/file_x/a.png',
        httpPut: (_) async =>
            IMBoyHttpResponse.failure(errMsg: 'boom', errCode: 1),
        readCurrent: () => <String, dynamic>{},
        saveLocal: (_) => savedCalled = true,
      );

      expect(ok, isFalse);
      expect(savedCalled, isFalse);
    });

    test('隐私设置字段写入 payload[setting] 而非顶层', () async {
      Map<String, dynamic>? savedPayload;

      final ok = await UserProfileService.updateField(
        'allow_search',
        false,
        httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
        readCurrent: () => <String, dynamic>{'setting': <String, dynamic>{}},
        saveLocal: (p) => savedPayload = p,
      );

      expect(ok, isTrue);
      expect(savedPayload!['setting'], isA<Map<String, dynamic>>());
      // QA#18: allow_search 后端权威值域 1|2，service 将 bool false 归一为 2 落缓存
      expect((savedPayload!['setting'] as Map)['allow_search'], 2);
      // 顶层不应混入该字段
      expect(savedPayload!.containsKey('allow_search'), isFalse);
    });

    test('setting 缺失或非 Map 时安全初始化为 Map', () async {
      Map<String, dynamic>? savedPayload;

      final ok = await UserProfileService.updateField(
        'show_online_status',
        true,
        httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
        // setting 字段缺失
        readCurrent: () => <String, dynamic>{'avatar': 'a'},
        saveLocal: (p) => savedPayload = p,
      );

      expect(ok, isTrue);
      expect(savedPayload!['setting'], isA<Map<String, dynamic>>());
      expect((savedPayload!['setting'] as Map)['show_online_status'], true);
    });
  });
}
