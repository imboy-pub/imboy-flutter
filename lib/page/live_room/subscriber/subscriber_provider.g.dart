// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscriber_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Subscriber Provider - 管理 WHEP 拉流状态和 PeerConnection

@ProviderFor(SubscriberNotifier)
final subscriberProvider = SubscriberNotifierProvider._();

/// Subscriber Provider - 管理 WHEP 拉流状态和 PeerConnection
final class SubscriberNotifierProvider
    extends $NotifierProvider<SubscriberNotifier, SubscriberState> {
  /// Subscriber Provider - 管理 WHEP 拉流状态和 PeerConnection
  SubscriberNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subscriberProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subscriberNotifierHash();

  @$internal
  @override
  SubscriberNotifier create() => SubscriberNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubscriberState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubscriberState>(value),
    );
  }
}

String _$subscriberNotifierHash() =>
    r'b72bddc9f0fa4a38e46f9f19dafed42561b56e0c';

/// Subscriber Provider - 管理 WHEP 拉流状态和 PeerConnection

abstract class _$SubscriberNotifier extends $Notifier<SubscriberState> {
  SubscriberState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SubscriberState, SubscriberState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SubscriberState, SubscriberState>,
              SubscriberState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
