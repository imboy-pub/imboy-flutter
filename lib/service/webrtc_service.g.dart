// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webrtc_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// WebRTC 服务 Provider

@ProviderFor(WebRTCNotifier)
final webRTCNotifierProvider = WebRTCNotifierProvider._();

/// WebRTC 服务 Provider
final class WebRTCNotifierProvider
    extends $NotifierProvider<WebRTCNotifier, WebRTCState> {
  /// WebRTC 服务 Provider
  WebRTCNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webRTCNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webRTCNotifierHash();

  @$internal
  @override
  WebRTCNotifier create() => WebRTCNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebRTCState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebRTCState>(value),
    );
  }
}

String _$webRTCNotifierHash() =>
    r'w3b4r5t6c7s8e9r0v1i2c3e4g5e6n7e8r9a0t1e2d3h4a5s6h';

/// WebRTC 服务 Provider

abstract class _$WebRTCNotifier extends $Notifier<WebRTCState> {
  WebRTCState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<WebRTCState, WebRTCState>;
    final element = ref.element
        as $ClassProviderElement<
          AnyNotifier<WebRTCState, WebRTCState>,
          WebRTCState,
          Object?,
          Object?
        >;
    element.handleCreate(ref, build);
  }
}
