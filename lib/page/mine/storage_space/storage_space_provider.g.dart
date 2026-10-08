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
    r'063e86e54c61ffa8a5cfbffe7b763b7054b14fb8';

abstract class _$StorageSpaceNotifier extends $Notifier<StorageSpaceState> {
  StorageSpaceState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StorageSpaceState, StorageSpaceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StorageSpaceState, StorageSpaceState>,
              StorageSpaceState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
