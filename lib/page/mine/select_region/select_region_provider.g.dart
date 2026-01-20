// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'select_region_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 选择地区 Provider

@ProviderFor(SelectRegionNotifier)
final selectRegionProvider = SelectRegionNotifierProvider._();

/// 选择地区 Provider
final class SelectRegionNotifierProvider
    extends $NotifierProvider<SelectRegionNotifier, SelectRegionState> {
  /// 选择地区 Provider
  SelectRegionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectRegionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectRegionNotifierHash();

  @$internal
  @override
  SelectRegionNotifier create() => SelectRegionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SelectRegionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SelectRegionState>(value),
    );
  }
}

String _$selectRegionNotifierHash() =>
    r'5ab843cf964c045349087fb663bb7373902dd7ff';

/// 选择地区 Provider

abstract class _$SelectRegionNotifier extends $Notifier<SelectRegionState> {
  SelectRegionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SelectRegionState, SelectRegionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SelectRegionState, SelectRegionState>,
              SelectRegionState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
