// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_gender_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 设置性别 Provider

@ProviderFor(SetGenderNotifier)
final setGenderProvider = SetGenderNotifierProvider._();

/// 设置性别 Provider
final class SetGenderNotifierProvider
    extends $NotifierProvider<SetGenderNotifier, SetGenderState> {
  /// 设置性别 Provider
  SetGenderNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setGenderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setGenderNotifierHash();

  @$internal
  @override
  SetGenderNotifier create() => SetGenderNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetGenderState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetGenderState>(value),
    );
  }
}

String _$setGenderNotifierHash() => r'45c6ea0dc4e622e43933910375bd93d71e01cce7';

/// 设置性别 Provider

abstract class _$SetGenderNotifier extends $Notifier<SetGenderState> {
  SetGenderState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SetGenderState, SetGenderState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SetGenderState, SetGenderState>,
              SetGenderState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
