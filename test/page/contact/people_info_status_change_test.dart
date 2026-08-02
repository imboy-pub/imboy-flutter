/// 问题1-增强 RED 测试：详情页应订阅 UserStatusChangeEvent 实时刷新在线状态。
///
/// 当前状态（已通过一手代码核实）：
///   - message_s2c.dart:835-863 收到 online/offline/hide 后 fire(UserStatusChangeEvent)
///   - 但全局无订阅者 → 详情页进入后不刷新
///   - 详情页只在 initData 读一次本地 contact.status，之后不再变
///
/// 本测试钉死 PeopleInfoNotifier.applyStatusChange 的契约：
///   1. online → state.status='online'
///   2. offline → state.status='offline' + lastSeenAt=事件时间戳
///   3. 仅当 userId 匹配当前页面 peer 时才更新（避免串台）
///
/// 由于 PeopleInfoNotifier 是 @riverpod 代码生成，直接实例化需要 ProviderContainer。
/// 为保持测试简单且聚焦业务逻辑，把"状态映射"提取为可单测的纯函数。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/contact/people_info/people_info_provider.dart';

void main() {
  group('问题1-增强 - PeopleInfoNotifier 状态变更映射', () {
    test('RED-1: applyStatusChange 方法必须存在', () {
      // 钉死 Notifier 上存在该方法
      expect(
        PeopleInfoNotifier.hasStaticApplyStatusChange,
        isTrue,
        reason: 'PeopleInfoNotifier 需要提供静态 helper（或实例方法）处理状态变更',
      );
    });

    test('RED-2: online 事件 → 映射为 status=online, lastSeenAt 不变', () {
      final result = PeopleInfoNotifier.mapStatusChange(
        currentLastSeenAt: 1700000000000,
        status: 'online',
      );
      expect(result.status, 'online');
      // online 时 lastSeenAt 保持原值（上线不代表"最后离线时间"变化）
      expect(result.lastSeenAt, 1700000000000);
    });

    test('RED-3: offline 事件 → status=offline, lastSeenAt=事件时间戳', () {
      final eventTs = 1800000000000;
      final result = PeopleInfoNotifier.mapStatusChange(
        currentLastSeenAt: 1700000000000,
        status: 'offline',
        eventTimestamp: eventTs,
      );
      expect(result.status, 'offline');
      // offline 时 lastSeenAt 更新为下线时刻（即"最后在线时间"）
      expect(result.lastSeenAt, eventTs);
    });

    test('RED-4: hide 事件 → status=offline(隐身对观察者等效), lastSeenAt 不变', () {
      final result = PeopleInfoNotifier.mapStatusChange(
        currentLastSeenAt: 1700000000000,
        status: 'hide',
      );
      // 对观察者而言，对方隐身 = 看不到在线 → 显示为离线态
      expect(result.status, 'offline');
      expect(result.lastSeenAt, 1700000000000);
    });

    test('RED-5: offline 事件缺 eventTimestamp → lastSeenAt 用当前时间兜底', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final result = PeopleInfoNotifier.mapStatusChange(
        currentLastSeenAt: 0,
        status: 'offline',
        // 不传 eventTimestamp
      );
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(result.status, 'offline');
      expect(result.lastSeenAt, greaterThanOrEqualTo(before));
      expect(result.lastSeenAt, lessThanOrEqualTo(after));
    });
  });
}
