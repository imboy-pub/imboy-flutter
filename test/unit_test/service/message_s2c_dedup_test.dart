import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_s2c.dart';

/// S2C 重复投递去重层「特征化测试」。
///
/// 固化当前（经核验为正确的）行为，防回归：
/// - 服务端按 2/5/7/11s 窗口重发未 ACK 的 S2C；接收端用帧 id 单点去重，
///   命中则跳过非幂等 action（force_offline / apply_friend 等）但仍回 ACK。
/// - 去重 TTL（常规 5min）必须 ≫ 服务端最大重发窗口（~11s），否则窗口内
///   重投会被当作新事件重复执行。
void main() {
  group('MessageS2CService 去重 key 构建', () {
    test('id 非空时直接用帧 id 作为去重 key', () {
      final key = MessageS2CService.buildS2CDedupKey(
        {'id': 'frame_123', 'server_ts': '1700000000'},
        'force_offline',
        '52278',
        '53314',
      );
      expect(key, 'frame_123');
    });

    test('id 缺失时回退到 action_from_to_serverTs 复合 key', () {
      final key = MessageS2CService.buildS2CDedupKey(
        {'server_ts': '1700000000'},
        'apply_friend',
        '52278',
        '53314',
      );
      expect(key, 'apply_friend_52278_53314_1700000000');
    });

    test('id 与 server_ts 均缺失时仍生成稳定（非空）复合 key', () {
      final key = MessageS2CService.buildS2CDedupKey(
        {},
        'user_muted',
        '52278',
        '53314',
      );
      expect(key, 'user_muted_52278_53314_');
    });

    test('空字符串 id 视为缺失，走回退分支', () {
      final key = MessageS2CService.buildS2CDedupKey(
        {'id': '', 'server_ts': '42'},
        'group_member_join',
        '1',
        '2',
      );
      expect(key, 'group_member_join_1_2_42');
    });
  });

  group('MessageS2CService 去重 TTL 不变量', () {
    // 服务端 S2C 重发节奏 2/5/7/11s，最大窗口约 11s。
    const serverMaxResendWindowMs = 11 * 1000;

    test('常规去重 TTL 远大于服务端最大重发窗口（否则窗口内重投会重复执行）', () {
      expect(
        MessageS2CService.s2cDedupTtlMs,
        greaterThan(serverMaxResendWindowMs),
      );
      // 固化当前值：5 分钟
      expect(MessageS2CService.s2cDedupTtlMs, 5 * 60 * 1000);
    });

    test('pull_offline_msg 用更短 TTL（跨重连可合法重发），且短于常规 TTL', () {
      expect(
        MessageS2CService.s2cPullOfflineTtlMs,
        lessThan(MessageS2CService.s2cDedupTtlMs),
      );
      expect(MessageS2CService.s2cPullOfflineTtlMs, 2 * 1000);
    });
  });
}
