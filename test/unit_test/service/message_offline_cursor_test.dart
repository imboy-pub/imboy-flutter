/// 离线消息拉取游标解析与持久化单元测试
///
/// 背景（D4 契约修复）：
/// - 后端 next_last_msg_at 现返回毫秒整数（与 *_last_msg_at 请求参数同单位）；
/// - 客户端需兼容历史后端直接回传 RFC3339 字符串的格式，否则游标恒 0、
///   每轮拉取退化为全量；
/// - 游标持久化到 StorageService，应用重启后恢复，避免冷启动全量重拉。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('extractNextCursor 游标解析', () {
    test('毫秒整数直接透传（当前后端契约）', () {
      final section = <String, dynamic>{'next_last_msg_at': 1780286400500};
      expect(MessageOfflineService.extractNextCursor(section), 1780286400500);
    });

    test('数值字符串按整数解析', () {
      expect(
        MessageOfflineService.extractNextCursor({
          'next_last_msg_at': '1780286400500',
        }),
        1780286400500,
      );
    });

    test('RFC3339 UTC 字符串转换为毫秒（历史后端格式）', () {
      expect(
        MessageOfflineService.extractNextCursor({
          'next_last_msg_at': '2026-06-01T04:00:00.500Z',
        }),
        1780286400500,
      );
    });

    test('RFC3339 带时区偏移字符串转换为毫秒（与 UTC 同一瞬间等值）', () {
      expect(
        MessageOfflineService.extractNextCursor({
          'next_last_msg_at': '2026-06-01T12:00:00.500+08:00',
        }),
        1780286400500,
      );
    });

    test('非法输入返回 null（游标保持不变，不误推进）', () {
      expect(
        MessageOfflineService.extractNextCursor({
          'next_last_msg_at': 'not-a-time',
        }),
        isNull,
      );
      expect(
        MessageOfflineService.extractNextCursor({'next_last_msg_at': null}),
        isNull,
      );
      expect(
        MessageOfflineService.extractNextCursor(<String, dynamic>{}),
        isNull,
      );
      expect(MessageOfflineService.extractNextCursor('not-a-map'), isNull);
      expect(MessageOfflineService.extractNextCursor(null), isNull);
    });
  });

  group('游标持久化', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
    });

    test('未写入时读取返回 0（全量拉取语义）', () {
      expect(MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c), 0);
    });

    test('写入后可读回（重启恢复路径）', () async {
      MessageOfflineService.persistCursor(Keys.offlineCursorC2c, 1780286400500);
      // persistCursor 是 fire-and-forget，让事件循环跑完异步写
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
        1780286400500,
      );
    });

    test('非正值不写入（避免把游标清零）', () async {
      MessageOfflineService.persistCursor(Keys.offlineCursorC2g, 0);
      MessageOfflineService.persistCursor(Keys.offlineCursorS2c, -1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        SharedPreferences.getInstance().then(
          (p) => p.getInt(Keys.offlineCursorC2g),
        ),
        completion(isNull),
      );
      expect(
        SharedPreferences.getInstance().then(
          (p) => p.getInt(Keys.offlineCursorS2c),
        ),
        completion(isNull),
      );
    });
  });
}
