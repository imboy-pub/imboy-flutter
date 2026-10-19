// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_scroll_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 消息滚动管理器
/// 处理消息列表的滚动、定位和动画效果
///
/// 注意：本类不拥有 [ScrollController]。controller 由聊天页 State 创建并在
/// dispose 时销毁，经 [attachScrollController] 注入。若由本类（autoDispose
/// provider）持有并在 ref.onDispose 中销毁，页面退出时 provider 回收与
/// Scrollable unmount 的时序不受控，惯性滚动动画仍会驱动已销毁的
/// controller，触发 "A ScrollController was used after being disposed"。

@ProviderFor(MessageScrollManager)
final messageScrollManagerProvider = MessageScrollManagerProvider._();

/// 消息滚动管理器
/// 处理消息列表的滚动、定位和动画效果
///
/// 注意：本类不拥有 [ScrollController]。controller 由聊天页 State 创建并在
/// dispose 时销毁，经 [attachScrollController] 注入。若由本类（autoDispose
/// provider）持有并在 ref.onDispose 中销毁，页面退出时 provider 回收与
/// Scrollable unmount 的时序不受控，惯性滚动动画仍会驱动已销毁的
/// controller，触发 "A ScrollController was used after being disposed"。
final class MessageScrollManagerProvider
    extends $NotifierProvider<MessageScrollManager, MessageScrollState> {
  /// 消息滚动管理器
  /// 处理消息列表的滚动、定位和动画效果
  ///
  /// 注意：本类不拥有 [ScrollController]。controller 由聊天页 State 创建并在
  /// dispose 时销毁，经 [attachScrollController] 注入。若由本类（autoDispose
  /// provider）持有并在 ref.onDispose 中销毁，页面退出时 provider 回收与
  /// Scrollable unmount 的时序不受控，惯性滚动动画仍会驱动已销毁的
  /// controller，触发 "A ScrollController was used after being disposed"。
  MessageScrollManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageScrollManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageScrollManagerHash();

  @$internal
  @override
  MessageScrollManager create() => MessageScrollManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageScrollState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageScrollState>(value),
    );
  }
}

String _$messageScrollManagerHash() =>
    r'59f47b884e15cdf0d5fd7fd6acc1ae03fb3024ad';

/// 消息滚动管理器
/// 处理消息列表的滚动、定位和动画效果
///
/// 注意：本类不拥有 [ScrollController]。controller 由聊天页 State 创建并在
/// dispose 时销毁，经 [attachScrollController] 注入。若由本类（autoDispose
/// provider）持有并在 ref.onDispose 中销毁，页面退出时 provider 回收与
/// Scrollable unmount 的时序不受控，惯性滚动动画仍会驱动已销毁的
/// controller，触发 "A ScrollController was used after being disposed"。

abstract class _$MessageScrollManager extends $Notifier<MessageScrollState> {
  MessageScrollState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MessageScrollState, MessageScrollState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MessageScrollState, MessageScrollState>,
              MessageScrollState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
