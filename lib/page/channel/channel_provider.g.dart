// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 频道列表 Notifier

@ProviderFor(ChannelListNotifier)
final channelListProvider = ChannelListNotifierProvider._();

/// 频道列表 Notifier
final class ChannelListNotifierProvider
    extends $NotifierProvider<ChannelListNotifier, ChannelListState> {
  /// 频道列表 Notifier
  ChannelListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$channelListNotifierHash();

  @$internal
  @override
  ChannelListNotifier create() => ChannelListNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChannelListState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChannelListState>(value),
    );
  }
}

String _$channelListNotifierHash() =>
    r'e4742d270951d8d31a2dbd75e3e3dec921859141';

/// 频道列表 Notifier

abstract class _$ChannelListNotifier extends $Notifier<ChannelListState> {
  ChannelListState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChannelListState, ChannelListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChannelListState, ChannelListState>,
              ChannelListState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// 频道详情 Notifier

@ProviderFor(ChannelDetailNotifier)
final channelDetailProvider = ChannelDetailNotifierProvider._();

/// 频道详情 Notifier
final class ChannelDetailNotifierProvider
    extends $NotifierProvider<ChannelDetailNotifier, ChannelDetailState> {
  /// 频道详情 Notifier
  ChannelDetailNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelDetailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$channelDetailNotifierHash();

  @$internal
  @override
  ChannelDetailNotifier create() => ChannelDetailNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChannelDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChannelDetailState>(value),
    );
  }
}

String _$channelDetailNotifierHash() =>
    r'36822cbbb7fa2dda8f4282730910e39fc8814dc4';

/// 频道详情 Notifier

abstract class _$ChannelDetailNotifier extends $Notifier<ChannelDetailState> {
  ChannelDetailState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChannelDetailState, ChannelDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChannelDetailState, ChannelDetailState>,
              ChannelDetailState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// 创建频道 Notifier

@ProviderFor(CreateChannelNotifier)
final createChannelProvider = CreateChannelNotifierProvider._();

/// 创建频道 Notifier
final class CreateChannelNotifierProvider
    extends $NotifierProvider<CreateChannelNotifier, CreateChannelState> {
  /// 创建频道 Notifier
  CreateChannelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'createChannelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$createChannelNotifierHash();

  @$internal
  @override
  CreateChannelNotifier create() => CreateChannelNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreateChannelState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreateChannelState>(value),
    );
  }
}

String _$createChannelNotifierHash() =>
    r'3a141f90ae57d4be663c3d8c0d2f97158cc18e58';

/// 创建频道 Notifier

abstract class _$CreateChannelNotifier extends $Notifier<CreateChannelState> {
  CreateChannelState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CreateChannelState, CreateChannelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CreateChannelState, CreateChannelState>,
              CreateChannelState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// 频道未读计数 Provider（简单同步版本，用于快速访问）

@ProviderFor(channelUnreadCount)
final channelUnreadCountProvider = ChannelUnreadCountProvider._();

/// 频道未读计数 Provider（简单同步版本，用于快速访问）

final class ChannelUnreadCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// 频道未读计数 Provider（简单同步版本，用于快速访问）
  ChannelUnreadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelUnreadCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$channelUnreadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return channelUnreadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$channelUnreadCountHash() =>
    r'2b864c1fe011da9bbf34ff94625c2a0e041b4c71';
