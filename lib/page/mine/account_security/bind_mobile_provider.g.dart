// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bind_mobile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BindMobileNotifier)
final bindMobileProvider = BindMobileNotifierProvider._();

final class BindMobileNotifierProvider
    extends $NotifierProvider<BindMobileNotifier, BindMobileState> {
  BindMobileNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bindMobileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bindMobileNotifierHash();

  @$internal
  @override
  BindMobileNotifier create() => BindMobileNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BindMobileState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BindMobileState>(value),
    );
  }
}

String _$bindMobileNotifierHash() =>
    r'5f83a543f7ed71152344cbd92bd644b7c0dbfe09';

abstract class _$BindMobileNotifier extends $Notifier<BindMobileState> {
  BindMobileState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<BindMobileState, BindMobileState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BindMobileState, BindMobileState>,
              BindMobileState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
