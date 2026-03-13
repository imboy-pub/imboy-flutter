// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_scroll_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 消息滚动管理器
/// 处理消息列表的滚动、定位和动画效果

@ProviderFor(MessageScrollManager)
final messageScrollManagerProvider = MessageScrollManagerProvider._();

/// 消息滚动管理器
/// 处理消息列表的滚动、定位和动画效果
final class MessageScrollManagerProvider
    extends $NotifierProvider<MessageScrollManager, MessageScrollState> {
  /// 消息滚动管理器
  /// 处理消息列表的滚动、定位和动画效果
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
    r'ce03435e811cdb88ab3533629a41baba23113dff';

/// 消息滚动管理器
/// 处理消息列表的滚动、定位和动画效果

abstract class _$MessageScrollManager extends $Notifier<MessageScrollState> {
  MessageScrollState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MessageScrollState, MessageScrollState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MessageScrollState, MessageScrollState>,
              MessageScrollState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
