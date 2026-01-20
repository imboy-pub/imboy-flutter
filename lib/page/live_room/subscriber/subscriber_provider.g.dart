// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscriber_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Subscriber Provider

@ProviderFor(SubscriberNotifier)
final subscriberProvider = SubscriberNotifierProvider._();

/// Subscriber Provider
final class SubscriberNotifierProvider
    extends $NotifierProvider<SubscriberNotifier, SubscriberState> {
  /// Subscriber Provider
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
    r'dbd76ed2e9e0a276dc5d6fec04ff0b2b16cc47c5';

/// Subscriber Provider

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
