/// 钉住 `GroupNoticeConfig` 的读写契约 —— slice-6 (C6 持久化子切片) RED-20。
///
/// 设计取舍：免打扰是**用户-设备本地偏好**，不需跨端同步 → 用 KV 键值
/// 而非 Group 表字段。优点：
///   1. 不引入 v20 migration（规避 win32 环境债务牵连）
///   2. 键格式 `group_notice_disabled:${gid}` 可 grep 定位
///   3. 函数注入 read/write 绕开 StorageService 单例 → 纯单测
///
/// W09.a（channel-group-ux-v2.2 §6.7）：键升级为账号范围
/// `group_notice_disabled:$accountUid:$gid`（J16.a 账号键隔离）。
///
/// 契约：
///   1. 默认 false（未设置 / 读返回 null）
///   2. `gid <= 0` 或 accountUid 为空 → 读返回 false、写拒绝（不污染 KV）
///   3. `setNoticeDisabled(gid, true)` → 同账号下次读为 true
///   4. `setNoticeDisabled(gid, false)` → 覆盖写（不 remove，保持语义明确）
///   5. 不同 gid 相互隔离
///   6. 不同 accountUid 相互隔离（同设备多账号，J16.a）
///   7. 旧无账号键 `group_notice_disabled:$gid` 不被新键路径读取
///      （保留不导入，默认 false）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_notice_config.dart';

void main() {
  group('groupNoticeDisabledKey — 键格式', () {
    test('账号+gid 转键名（含账号段前缀）', () {
      expect(
        groupNoticeDisabledKey('1001', 10),
        'group_notice_disabled:1001:10',
      );
      expect(
        groupNoticeDisabledKey('1002', 999999),
        'group_notice_disabled:1002:999999',
      );
    });
  });

  group('readNoticeDisabled — 读契约', () {
    test('未设置（读返回 null）→ false', () {
      bool? readBool(String _) => null;
      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: readBool),
        isFalse,
      );
    });

    test('已设置为 true → true', () {
      bool? readBool(String k) =>
          k == 'group_notice_disabled:1001:10' ? true : null;
      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: readBool),
        isTrue,
      );
    });

    test('已设置为 false → false', () {
      bool? readBool(String _) => false;
      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: readBool),
        isFalse,
      );
    });

    test('gid <= 0 → 总是 false，不调 readBool', () {
      var called = false;
      bool? readBool(String _) {
        called = true;
        return true;
      }

      expect(
        readNoticeDisabled(0, accountUid: '1001', readBool: readBool),
        isFalse,
      );
      expect(
        readNoticeDisabled(-1, accountUid: '1001', readBool: readBool),
        isFalse,
      );
      expect(called, isFalse, reason: '非法 gid 不应触发实际读取');
    });

    test('J16.a：accountUid 为空（未登录）→ false，不读共享旧键', () {
      var called = false;
      bool? readBool(String _) {
        called = true;
        return true;
      }

      expect(
        readNoticeDisabled(10, accountUid: '', readBool: readBool),
        isFalse,
      );
      expect(called, isFalse, reason: '空账号不应触发任何 KV 读取');
    });

    test('J16.a：同设备两账号相互隔离', () {
      final kv = <String, bool>{'group_notice_disabled:1001:10': true};
      bool? read(String k) => kv[k];
      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: read),
        isTrue,
      );
      expect(
        readNoticeDisabled(10, accountUid: '1002', readBool: read),
        isFalse,
        reason: '账号 1002 的键域与 1001 隔离',
      );
    });

    test('J16.a：旧无账号键保留不导入（新键路径读不到）', () {
      final kv = <String, bool>{
        'group_notice_disabled:10': true, // 旧键（无可信所有者）
      };
      bool? read(String k) => kv[k];
      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: read),
        isFalse,
        reason: '旧键不自动导入当前账号，默认 false',
      );
    });
  });

  group('setNoticeDisabled — 写契约', () {
    test('合法 gid + true → 调 writeBool(账号键, true)', () async {
      final writes = <(String, bool)>[];
      await setNoticeDisabled(
        10,
        true,
        accountUid: '1001',
        writeBool: (k, v) async => writes.add((k, v)),
      );
      expect(writes, [('group_notice_disabled:1001:10', true)]);
    });

    test('合法 gid + false → 覆盖写 false（非 remove）', () async {
      final writes = <(String, bool)>[];
      await setNoticeDisabled(
        10,
        false,
        accountUid: '1001',
        writeBool: (k, v) async => writes.add((k, v)),
      );
      expect(writes, [('group_notice_disabled:1001:10', false)]);
    });

    test('gid <= 0 或账号为空 → 拒绝写入，不调 writeBool', () async {
      var called = false;
      Future<void> write(String _, bool ignored) async => called = true;
      await setNoticeDisabled(0, true, accountUid: '1001', writeBool: write);
      await setNoticeDisabled(-5, true, accountUid: '1001', writeBool: write);
      await setNoticeDisabled(10, true, accountUid: '', writeBool: write);
      expect(called, isFalse, reason: '脏 gid/空账号均不得写入 KV');
    });

    test('不同 gid 与不同账号相互隔离', () async {
      final writes = <(String, bool)>[];
      await setNoticeDisabled(
        10,
        true,
        accountUid: '1001',
        writeBool: (k, v) async => writes.add((k, v)),
      );
      await setNoticeDisabled(
        20,
        false,
        accountUid: '1001',
        writeBool: (k, v) async => writes.add((k, v)),
      );
      await setNoticeDisabled(
        10,
        true,
        accountUid: '1002',
        writeBool: (k, v) async => writes.add((k, v)),
      );
      expect(writes, [
        ('group_notice_disabled:1001:10', true),
        ('group_notice_disabled:1001:20', false),
        ('group_notice_disabled:1002:10', true),
      ]);
    });
  });

  group('集成：读写闭环（内存 Map stub）', () {
    test('相邻大群 ID 不共享免打扰设置', () async {
      final kv = <String, bool>{};
      await setNoticeDisabled(
        '9007199254740992',
        true,
        accountUid: '1001',
        writeBool: (k, v) async => kv[k] = v,
      );
      expect(
        readNoticeDisabled(
          '9007199254740992',
          accountUid: '1001',
          readBool: (k) => kv[k],
        ),
        isTrue,
      );
      expect(
        readNoticeDisabled(
          '9007199254740993',
          accountUid: '1001',
          readBool: (k) => kv[k],
        ),
        isFalse,
      );
    });
    test('set 后 read 返回同值；不同 gid/账号隔离', () async {
      final kv = <String, bool>{};
      bool? read(String k) => kv[k];
      Future<void> write(String k, bool v) async {
        kv[k] = v;
      }

      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: read),
        isFalse,
      );
      await setNoticeDisabled(10, true, accountUid: '1001', writeBool: write);
      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: read),
        isTrue,
      );
      expect(
        readNoticeDisabled(20, accountUid: '1001', readBool: read),
        isFalse,
      );
      expect(
        readNoticeDisabled(10, accountUid: '1002', readBool: read),
        isFalse,
      );

      await setNoticeDisabled(10, false, accountUid: '1001', writeBool: write);
      expect(
        readNoticeDisabled(10, accountUid: '1001', readBool: read),
        isFalse,
      );
    });
  });
}
