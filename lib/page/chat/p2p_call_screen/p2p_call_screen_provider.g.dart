// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'p2p_call_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// P2P Call Screen Provider

@ProviderFor(P2pCallScreenNotifier)
final p2pCallScreenProvider = P2pCallScreenNotifierProvider._();

/// P2P Call Screen Provider
final class P2pCallScreenNotifierProvider
    extends $NotifierProvider<P2pCallScreenNotifier, P2pCallScreenState> {
  /// P2P Call Screen Provider
  P2pCallScreenNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'p2pCallScreenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$p2pCallScreenNotifierHash();

  @$internal
  @override
  P2pCallScreenNotifier create() => P2pCallScreenNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(P2pCallScreenState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<P2pCallScreenState>(value),
    );
  }
}

String _$p2pCallScreenNotifierHash() =>
    r'cf07a1ad930902a3ddf8cdb775ff89d717eb2cab';

/// P2P Call Screen Provider

abstract class _$P2pCallScreenNotifier extends $Notifier<P2pCallScreenState> {
  P2pCallScreenState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<P2pCallScreenState, P2pCallScreenState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<P2pCallScreenState, P2pCallScreenState>,
              P2pCallScreenState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
