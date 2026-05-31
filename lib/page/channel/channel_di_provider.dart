import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/api/channel_api.dart';

/// Channel 依赖注入 Provider（手写，不使用 @riverpod 代码生成）
///
/// 目的：将页面层对 `ChannelApi()` 直接实例化与 `ChannelService.to` 单例
/// 的硬编码依赖，收敛为可在测试中通过 `ProviderScope(overrides: [...])`
/// 注入 mock 的依赖获取方式。
///
/// 业务逻辑保持不变，仅替换依赖获取方式：
/// - 生产环境：`channelApiProvider` 返回真实 `ChannelApi()`，
///   `channelServiceProvider` 返回真实单例 `ChannelService.to`。
/// - 测试环境：通过 override 注入 mock，使页面 widget 可测。

/// 提供 [ChannelApi] 实例。
///
/// 默认返回真实 `ChannelApi()`，与原 `ChannelApi()` 直接实例化等价。
final channelApiProvider = Provider<ChannelApi>((ref) {
  return ChannelApi();
});

/// 提供 [ChannelService] 实例。
///
/// 默认返回真实单例 `ChannelService.to`，与原 `ChannelService.to` 等价。
final channelServiceProvider = Provider<ChannelService>((ref) {
  return ChannelService.to;
});
