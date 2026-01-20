// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_loading_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 消息加载管理器
/// 处理消息的预加载、缓存和分页加载逻辑

@ProviderFor(MessageLoadingManager)
final messageLoadingManagerProvider = MessageLoadingManagerProvider._();

/// 消息加载管理器
/// 处理消息的预加载、缓存和分页加载逻辑
final class MessageLoadingManagerProvider
    extends $NotifierProvider<MessageLoadingManager, MessageLoadingState> {
  /// 消息加载管理器
  /// 处理消息的预加载、缓存和分页加载逻辑
  MessageLoadingManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageLoadingManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageLoadingManagerHash();

  @$internal
  @override
  MessageLoadingManager create() => MessageLoadingManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageLoadingState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageLoadingState>(value),
    );
  }
}

String _$messageLoadingManagerHash() =>
    r'6651e20b54ca68e67f063bf2d7992265f500a259';

/// 消息加载管理器
/// 处理消息的预加载、缓存和分页加载逻辑

abstract class _$MessageLoadingManager extends $Notifier<MessageLoadingState> {
  MessageLoadingState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MessageLoadingState, MessageLoadingState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MessageLoadingState, MessageLoadingState>,
              MessageLoadingState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
