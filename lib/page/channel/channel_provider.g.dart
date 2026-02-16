// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChannelListNotifier)
final channelListNotifierProvider = ChannelListNotifierProvider._();

final class ChannelListNotifierProvider
    extends $NotifierProvider<ChannelListNotifier, ChannelListState> {
  ChannelListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelListNotifierProvider',
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

String _$channelListNotifierHash() => r'channel_list_notifier_hash_placeholder';

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

@ProviderFor(ChannelDetailNotifier)
final channelDetailNotifierProvider = ChannelDetailNotifierProvider._();

final class ChannelDetailNotifierProvider
    extends $NotifierProvider<ChannelDetailNotifier, ChannelDetailState> {
  ChannelDetailNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'channelDetailNotifierProvider',
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
    r'channel_detail_notifier_hash_placeholder';

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

@ProviderFor(CreateChannelNotifier)
final createChannelNotifierProvider = CreateChannelNotifierProvider._();

final class CreateChannelNotifierProvider
    extends $NotifierProvider<CreateChannelNotifier, CreateChannelState> {
  CreateChannelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'createChannelNotifierProvider',
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
    r'create_channel_notifier_hash_placeholder';

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

@ProviderFor(channelUnreadCount)
final channelUnreadCountProvider = ChannelUnreadCountProvider._();

final class ChannelUnreadCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
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

String _$channelUnreadCountHash() => r'channel_unread_count_hash_placeholder';
