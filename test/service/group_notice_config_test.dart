/// 钉住 `GroupNoticeConfig` 的读写契约 —— slice-6 (C6 持久化子切片) RED-20。
///
/// 设计取舍：免打扰是**用户-设备本地偏好**，不需跨端同步 → 用 KV 键值
/// 而非 Group 表字段。优点：
///   1. 不引入 v20 migration（规避 win32 环境债务牵连）
///   2. 键格式 `group_notice_disabled:${gid}` 可 grep 定位
///   3. 函数注入 read/write 绕开 StorageService 单例 → 纯单测
///
/// 契约：
///   1. 默认 false（未设置 / 读返回 null）
///   2. `gid <= 0` → 读返回 false、写拒绝（不污染 KV）
///   3. `setNoticeDisabled(gid, true)` → 下次读为 true
///   4. `setNoticeDisabled(gid, false)` → 覆盖写（不 remove，保持语义明确）
///   5. 不同 gid 相互隔离
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_notice_config.dart';

void main() {
  group('groupNoticeDisabledKey — 键格式', () {
    test('合法 gid 转键名（group_notice_disabled: 前缀）', () {
      expect(groupNoticeDisabledKey(10), 'group_notice_disabled:10');
      expect(groupNoticeDisabledKey(999999), 'group_notice_disabled:999999');
    });
  });

  group('readNoticeDisabled — 读契约', () {
    test('未设置（读返回 null）→ false', () {
      bool? readBool(String _) => null;
      expect(readNoticeDisabled(10, readBool: readBool), isFalse);
    });

    test('已设置为 true → true', () {
      bool? readBool(String k) =>
          k == 'group_notice_disabled:10' ? true : null;
      expect(readNoticeDisabled(10, readBool: readBool), isTrue);
    });

    test('已设置为 false → false', () {
      bool? readBool(String _) => false;
      expect(readNoticeDisabled(10, readBool: readBool), isFalse);
    });

    test('gid <= 0 → 总是 false，不调 readBool', () {
      var called = false;
      bool? readBool(String _) {
        called = true;
        return true;
      }
      expect(readNoticeDisabled(0, readBool: readBool), isFalse);
      expect(readNoticeDisabled(-1, readBool: readBool), isFalse);
      expect(called, isFalse, reason: '非法 gid 不应触发实际读取');
    });
  });

  group('setNoticeDisabled — 写契约', () {
    test('合法 gid + true → 调 writeBool(key, true)', () async {
      final writes = <(String, bool)>[];
      await setNoticeDisabled(
        10,
        true,
        writeBool: (k, v) async => writes.add((k, v)),
      );
      expect(writes, [('group_notice_disabled:10', true)]);
    });

    test('合法 gid + false → 覆盖写 false（非 remove）', () async {
      final writes = <(String, bool)>[];
      await setNoticeDisabled(
        10,
        false,
        writeBool: (k, v) async => writes.add((k, v)),
      );
      expect(writes, [('group_notice_disabled:10', false)]);
    });

    test('gid <= 0 → 拒绝写入，不调 writeBool', () async {
      var called = false;
      await setNoticeDisabled(
        0,
        true,
        writeBool: (_, _) async => called = true,
      );
      await setNoticeDisabled(
        -5,
        true,
        writeBool: (_, _) async => called = true,
      );
      expect(called, isFalse);
    });

    test('不同 gid 相互隔离', () async {
      final writes = <(String, bool)>[];
      await setNoticeDisabled(
        10,
        true,
        writeBool: (k, v) async => writes.add((k, v)),
      );
      await setNoticeDisabled(
        20,
        false,
        writeBool: (k, v) async => writes.add((k, v)),
      );
      expect(writes, [
        ('group_notice_disabled:10', true),
        ('group_notice_disabled:20', false),
      ]);
    });
  });

  group('集成：读写闭环（内存 Map stub）', () {
    test('set 后 read 返回同值；不同 gid 隔离', () async {
      final kv = <String, bool>{};
      bool? read(String k) => kv[k];
      Future<void> write(String k, bool v) async {
        kv[k] = v;
      }

      expect(readNoticeDisabled(10, readBool: read), isFalse);
      await setNoticeDisabled(10, true, writeBool: write);
      expect(readNoticeDisabled(10, readBool: read), isTrue);
      expect(readNoticeDisabled(20, readBool: read), isFalse);

      await setNoticeDisabled(10, false, writeBool: write);
      expect(readNoticeDisabled(10, readBool: read), isFalse);
    });
  });
}
