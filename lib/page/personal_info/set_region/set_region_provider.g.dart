// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_region_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 设置地区 Provider

@ProviderFor(SetRegionNotifier)
final setRegionProvider = SetRegionNotifierProvider._();

/// 设置地区 Provider
final class SetRegionNotifierProvider
    extends $NotifierProvider<SetRegionNotifier, SetRegionState> {
  /// 设置地区 Provider
  SetRegionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setRegionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setRegionNotifierHash();

  @$internal
  @override
  SetRegionNotifier create() => SetRegionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetRegionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetRegionState>(value),
    );
  }
}

String _$setRegionNotifierHash() => r'549764aa945f59d1a4069f84100ca0e5a4219842';

/// 设置地区 Provider

abstract class _$SetRegionNotifier extends $Notifier<SetRegionState> {
  SetRegionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SetRegionState, SetRegionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SetRegionState, SetRegionState>,
              SetRegionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
