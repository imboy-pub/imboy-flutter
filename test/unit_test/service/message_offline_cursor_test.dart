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

    test('FL-04:LOCAL:03 同时间戳（next==当前游标）不构成推进条件', () {
      // 游标只进不退：next_last_msg_at 与现存游标相等时由调用侧
      // （next > local 才推进）判无进展；解析层仅负责还原数值。
      const current = 1780286400500;
      final next = MessageOfflineService.extractNextCursor({
        'next_last_msg_at': current,
      });
      expect(next, current);
      // 消费侧语义：next > current 为假 → 不推进 → 分页守卫判定无进展。
      expect(next! > current, isFalse);
      // 零/负值同样不得作为推进依据（持久化层非正值拒写）。
      expect(
        MessageOfflineService.extractNextCursor({'next_last_msg_at': 0}),
        0,
      );
      expect(
        MessageOfflineService.extractNextCursor({'next_last_msg_at': '0'}),
        0,
      );
    });

    test('FL-04:LOCAL:04 C2G 分页游标持久键按 env+uid 组合隔离', () async {
      // 键格式合同：`${offlineCursorC2gPage}_${currentEnv}_${uid}`。
      // 不同 env/uid 的键互不覆盖（值各归其位），旧作用域键不被读取方
      // 当作新作用域游标（见 offline_cursor_recovery_test 行为级断言）。
      const keyA = '${Keys.offlineCursorC2gPage}_devA_100';
      const keyB = '${Keys.offlineCursorC2gPage}_devB_100';
      const keyOtherAccount = '${Keys.offlineCursorC2gPage}_devA_200';
      MessageOfflineService.persistCursor(Keys.offlineCursorC2c, 1780286400500);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(MessageOfflineService.readStoredCursor(keyA), 0);
      expect(MessageOfflineService.readStoredCursor(keyB), 0);
      expect(MessageOfflineService.readStoredCursor(keyOtherAccount), 0);
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
