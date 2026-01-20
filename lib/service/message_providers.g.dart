// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// MessageService Provider
/// 消息核心服务 Provider
///
/// 提供单例的 MessageService 实例

@ProviderFor(messageService)
final messageServiceProvider = MessageServiceProvider._();

/// MessageService Provider
/// 消息核心服务 Provider
///
/// 提供单例的 MessageService 实例

final class MessageServiceProvider
    extends $FunctionalProvider<MessageService, MessageService, MessageService>
    with $Provider<MessageService> {
  /// MessageService Provider
  /// 消息核心服务 Provider
  ///
  /// 提供单例的 MessageService 实例
  MessageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageServiceHash();

  @$internal
  @override
  $ProviderElement<MessageService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MessageService create(Ref ref) {
    return messageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageService>(value),
    );
  }
}

String _$messageServiceHash() => r'8f959b1bcbdd71cc9099a868a751c64d1ac45940';

/// MessageActions Provider
/// 消息操作服务 Provider
///
/// 提供单例的 MessageActions 实例

@ProviderFor(messageActions)
final messageActionsProvider = MessageActionsProvider._();

/// MessageActions Provider
/// 消息操作服务 Provider
///
/// 提供单例的 MessageActions 实例

final class MessageActionsProvider
    extends $FunctionalProvider<MessageActions, MessageActions, MessageActions>
    with $Provider<MessageActions> {
  /// MessageActions Provider
  /// 消息操作服务 Provider
  ///
  /// 提供单例的 MessageActions 实例
  MessageActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageActionsHash();

  @$internal
  @override
  $ProviderElement<MessageActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MessageActions create(Ref ref) {
    return messageActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageActions>(value),
    );
  }
}

String _$messageActionsHash() => r'9af5426862f9490269cefe1afe68976c26c9283b';

/// MessageWebrtc Provider
/// WebRTC 消息服务 Provider
///
/// 提供单例的 MessageWebrtc 实例

@ProviderFor(messageWebrtc)
final messageWebrtcProvider = MessageWebrtcProvider._();

/// MessageWebrtc Provider
/// WebRTC 消息服务 Provider
///
/// 提供单例的 MessageWebrtc 实例

final class MessageWebrtcProvider
    extends $FunctionalProvider<MessageWebrtc, MessageWebrtc, MessageWebrtc>
    with $Provider<MessageWebrtc> {
  /// MessageWebrtc Provider
  /// WebRTC 消息服务 Provider
  ///
  /// 提供单例的 MessageWebrtc 实例
  MessageWebrtcProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageWebrtcProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageWebrtcHash();

  @$internal
  @override
  $ProviderElement<MessageWebrtc> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MessageWebrtc create(Ref ref) {
    return messageWebrtc(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageWebrtc value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageWebrtc>(value),
    );
  }
}

String _$messageWebrtcHash() => r'6f802d9d030fcd18988d52e2be9a878c493994c9';

/// MessageS2CService Provider
/// S2C 消息服务 Provider
///
/// 提供单例的 MessageS2CService 实例

@ProviderFor(messageS2CService)
final messageS2CServiceProvider = MessageS2CServiceProvider._();

/// MessageS2CService Provider
/// S2C 消息服务 Provider
///
/// 提供单例的 MessageS2CService 实例

final class MessageS2CServiceProvider
    extends
        $FunctionalProvider<
          MessageS2CService,
          MessageS2CService,
          MessageS2CService
        >
    with $Provider<MessageS2CService> {
  /// MessageS2CService Provider
  /// S2C 消息服务 Provider
  ///
  /// 提供单例的 MessageS2CService 实例
  MessageS2CServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageS2CServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageS2CServiceHash();

  @$internal
  @override
  $ProviderElement<MessageS2CService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MessageS2CService create(Ref ref) {
    return messageS2CService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageS2CService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageS2CService>(value),
    );
  }
}

String _$messageS2CServiceHash() => r'cb2e0f55594eb9aa142672a0fb4052116688cbfc';
