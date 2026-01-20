// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 更新页面 Provider

@ProviderFor(UpdatePageNotifier)
final updatePageProvider = UpdatePageNotifierProvider._();

/// 更新页面 Provider
final class UpdatePageNotifierProvider
    extends $NotifierProvider<UpdatePageNotifier, UpdatePageState> {
  /// 更新页面 Provider
  UpdatePageNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updatePageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updatePageNotifierHash();

  @$internal
  @override
  UpdatePageNotifier create() => UpdatePageNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdatePageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdatePageState>(value),
    );
  }
}

String _$updatePageNotifierHash() =>
    r'e88f31b57bc4acc1c91504e038d217ba5e4127d2';

/// 更新页面 Provider

abstract class _$UpdatePageNotifier extends $Notifier<UpdatePageState> {
  UpdatePageState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<UpdatePageState, UpdatePageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdatePageState, UpdatePageState>,
              UpdatePageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
