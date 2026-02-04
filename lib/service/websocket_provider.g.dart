// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocket_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WebSocketStatusNotifier)
final webSocketStatusProvider = WebSocketStatusNotifierProvider._();

final class WebSocketStatusNotifierProvider
    extends $NotifierProvider<WebSocketStatusNotifier, SocketStatus> {
  WebSocketStatusNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'webSocketStatusProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$webSocketStatusNotifierHash();

  @$internal
  @override
  WebSocketStatusNotifier create() => WebSocketStatusNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocketStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocketStatus>(value),
    );
  }
}

String _$webSocketStatusNotifierHash() =>
    r'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0';

abstract class _$WebSocketStatusNotifier extends $Notifier<SocketStatus> {
  SocketStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SocketStatus, SocketStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SocketStatus, SocketStatus>,
              SocketStatus,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
