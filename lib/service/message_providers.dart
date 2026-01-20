/// Message Service Providers
///
/// 消息服务的 Riverpod Provider 定义
/// 统一管理所有消息相关的服务实例
///
/// ## 架构说明
///
/// 所有服务通过 Riverpod Provider 提供，支持：
/// - 单例模式（通过 `Provider`）
/// - 依赖注入
/// - 测试时可以替换实现
///
/// ## 使用方式
///
/// ```dart
/// // 在 ConsumerWidget 中使用
/// class MyPage extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final messageService = ref.watch(messageServiceProvider);
///     // 使用服务...
///   }
/// }
///
/// // 在普通 Dart 代码中（通过 ProviderContainer）
/// final container = ProviderContainer();
/// final messageService = container.read(messageServiceProvider);
/// ```
///
/// ## 服务依赖关系
///
/// ```
/// MessageService (核心服务)
///   ├── MessageActions (消息操作)
///   ├── MessageWebrtc (WebRTC)
///   ├── MessageS2CService (S2C消息)
///   └── 依赖: ConversationProvider, ContactApi
/// ```
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'message.dart';
import 'message_actions.dart';
import 'message_s2c.dart';
import 'message_webrtc.dart';

part 'message_providers.g.dart';

/// MessageService Provider
/// 消息核心服务 Provider
///
/// 提供单例的 MessageService 实例
@riverpod
MessageService messageService(Ref ref) {
  return MessageService.instance;
}

/// MessageActions Provider
/// 消息操作服务 Provider
///
/// 提供单例的 MessageActions 实例
@riverpod
MessageActions messageActions(Ref ref) {
  return MessageActions.instance;
}

/// MessageWebrtc Provider
/// WebRTC 消息服务 Provider
///
/// 提供单例的 MessageWebrtc 实例
@riverpod
MessageWebrtc messageWebrtc(Ref ref) {
  return MessageWebrtc.instance;
}

/// MessageS2CService Provider
/// S2C 消息服务 Provider
///
/// 提供单例的 MessageS2CService 实例
@riverpod
MessageS2CService messageS2CService(Ref ref) {
  return MessageS2CService();
}
