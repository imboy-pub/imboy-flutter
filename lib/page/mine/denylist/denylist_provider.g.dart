// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'denylist_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DenylistNotifier)
final denylistProvider = DenylistNotifierProvider._();

final class DenylistNotifierProvider
    extends $NotifierProvider<DenylistNotifier, DenylistState> {
  DenylistNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'denylistProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$denylistNotifierHash();

  @$internal
  @override
  DenylistNotifier create() => DenylistNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DenylistState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DenylistState>(value),
    );
  }
}

String _$denylistNotifierHash() => r'7c5d5a1f2bcbfafad0ec92985d86b533414efb74';

abstract class _$DenylistNotifier extends $Notifier<DenylistState> {
  DenylistState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DenylistState, DenylistState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DenylistState, DenylistState>,
              DenylistState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
