// AppDowngradeCleaner 的生产实现
// Production implementation of AppDowngradeCleaner
//
// 降级时清理协议/策略相关本地缓存，保留用户身份与持久数据：
//
// 清理（协议/策略）：
// - ws_message_queue         WS v2.0 消息格式与旧版不兼容（msg_type/action/e2ee 字段）
// - app_upgrade_dismissed_vsn 降级后应重新提示升级（用户可能误回退）
// - app_upgrade_last_check_time 同上
//
// 保留（用户资产）：
// - secure_token / secure_refresh_token  清理会强退登录
// - e2ee 密钥对 / 会话密钥               清理会丢失历史消息解密能力
// - 用户资料、联系人、会话列表            业务数据
//
// 清理行为幂等，通过 remove() 调用（不存在的 key 也不会报错）。
//
// Downgrade-time purge of protocol/strategy caches; preserves user identity
// and persistent data. Purges ws_message_queue / upgrade-dismiss records.
// Preserves tokens, e2ee keys, and user-owned data. Idempotent.
library;

import 'package:imboy/service/app_downgrade_cleaner.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/upgrade_strategy.dart';

class DefaultAppDowngradeCleaner implements AppDowngradeCleaner {
  /// 构造注入存储实现（默认使用 `StorageService.to` 单例）。
  /// Storage implementation is injected (defaults to `StorageService.to`).
  ///
  /// 测试时传入 FakeStorage 以避免 SharedPreferences 平台通道。
  /// Tests pass a FakeStorage to avoid SharedPreferences platform channels.
  DefaultAppDowngradeCleaner({dynamic storage})
      : _storage = storage ?? StorageService.to;

  /// WebSocket 消息队列存储 key（与 websocket_message_queue.dart 同步）。
  /// WebSocket message queue storage key (kept in sync with source file).
  static const String wsMessageQueueKey = 'ws_message_queue';

  final dynamic _storage; // duck-typed: remove(key)

  @override
  Future<void> onDowngrade({
    required String fromVsn,
    required String toVsn,
  }) async {
    // 协议不兼容：WS API v2.0 → v1.x 字段结构变更
    // Protocol incompatibility: WS API v2.0 → v1.x field-structure change
    _storage.remove(wsMessageQueueKey);

    // 策略重置：降级后应重新提示升级
    // Strategy reset: prompt upgrade again after downgrade
    _storage.remove(AppUpgradeDismissState.dismissedVsnKey);
    _storage.remove(AppUpgradeDismissState.lastCheckTimeKey);
  }
}
