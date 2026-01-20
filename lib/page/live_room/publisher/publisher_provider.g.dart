// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publisher_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Publisher Provider

@ProviderFor(PublisherNotifier)
final publisherProvider = PublisherNotifierProvider._();

/// Publisher Provider
final class PublisherNotifierProvider
    extends $NotifierProvider<PublisherNotifier, PublisherState> {
  /// Publisher Provider
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

String _$publisherNotifierHash() => r'cead20d8f6566328a4b7f44166b465ad88316d38';

/// Publisher Provider

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
