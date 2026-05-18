// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publisher_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Publisher Provider - 管理 WHIP 推流状态和 PeerConnection

@ProviderFor(PublisherNotifier)
final publisherProvider = PublisherNotifierProvider._();

/// Publisher Provider - 管理 WHIP 推流状态和 PeerConnection
final class PublisherNotifierProvider
    extends $NotifierProvider<PublisherNotifier, PublisherState> {
  /// Publisher Provider - 管理 WHIP 推流状态和 PeerConnection
  PublisherNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publisherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publisherNotifierHash();

  @$internal
  @override
  PublisherNotifier create() => PublisherNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PublisherState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PublisherState>(value),
    );
  }
}

String _$publisherNotifierHash() => r'6d78dcef362654dc222006c7683ad591e95d1b50';

/// Publisher Provider - 管理 WHIP 推流状态和 PeerConnection

abstract class _$PublisherNotifier extends $Notifier<PublisherState> {
  PublisherState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PublisherState, PublisherState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PublisherState, PublisherState>,
              PublisherState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
