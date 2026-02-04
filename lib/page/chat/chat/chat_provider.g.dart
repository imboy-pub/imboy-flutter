// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 消息处理服务 Provider
/// 提供消息发送、删除、收藏等操作

@ProviderFor(messageHandlingService)
final messageHandlingServiceProvider = MessageHandlingServiceProvider._();

/// 消息处理服务 Provider
/// 提供消息发送、删除、收藏等操作

final class MessageHandlingServiceProvider
    extends
        $FunctionalProvider<
          MessageHandlingService,
          MessageHandlingService,
          MessageHandlingService
        >
    with $Provider<MessageHandlingService> {
  /// 消息处理服务 Provider
  /// 提供消息发送、删除、收藏等操作
  MessageHandlingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageHandlingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageHandlingServiceHash();

  @$internal
  @override
  $ProviderElement<MessageHandlingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MessageHandlingService create(Ref ref) {
    return messageHandlingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageHandlingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageHandlingService>(value),
    );
  }
}

String _$messageHandlingServiceHash() =>
    r'f23ee30a6eda631f8b0e388a249fd341a24247a3';

/// 聊天 Provider（Riverpod Notifier 实现）
///
/// 这是聊天模块的核心状态管理类，使用 Riverpod 的 Notifier 模式

@ProviderFor(ChatNotifier)
final chatProvider = ChatNotifierProvider._();

/// 聊天 Provider（Riverpod Notifier 实现）
///
/// 这是聊天模块的核心状态管理类，使用 Riverpod 的 Notifier 模式
final class ChatNotifierProvider
    extends $NotifierProvider<ChatNotifier, ChatState> {
  /// 聊天 Provider（Riverpod Notifier 实现）
  ///
  /// 这是聊天模块的核心状态管理类，使用 Riverpod 的 Notifier 模式
  ChatNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatNotifierHash();

  @$internal
  @override
  ChatNotifier create() => ChatNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatState>(value),
    );
  }
}

String _$chatNotifierHash() => r'c6faf6ec92ae3c1c659de26c95f9c7bea0b148fe';

/// 聊天 Provider（Riverpod Notifier 实现）
///
/// 这是聊天模块的核心状态管理类，使用 Riverpod 的 Notifier 模式

abstract class _$ChatNotifier extends $Notifier<ChatState> {
  ChatState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChatState, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatState, ChatState>,
              ChatState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
