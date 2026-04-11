// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_space_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StorageSpaceNotifier)
final storageSpaceProvider = StorageSpaceNotifierProvider._();

final class StorageSpaceNotifierProvider
    extends $NotifierProvider<StorageSpaceNotifier, StorageSpaceState> {
  StorageSpaceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageSpaceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageSpaceNotifierHash();

  @$internal
  @override
  StorageSpaceNotifier create() => StorageSpaceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageSpaceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageSpaceState>(value),
    );
  }
}

String _$storageSpaceNotifierHash() =>
    r'5125d408ca0ffd1aa65011b7079dd5211bde96f7';

abstract class _$StorageSpaceNotifier extends $Notifier<StorageSpaceState> {
  StorageSpaceState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<StorageSpaceState, StorageSpaceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StorageSpaceState, StorageSpaceState>,
              StorageSpaceState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
