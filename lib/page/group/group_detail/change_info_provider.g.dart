// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 修改群信息 Notifier

@ProviderFor(ChangeInfoNotifier)
final changeInfoProvider = ChangeInfoNotifierProvider._();

/// 修改群信息 Notifier
final class ChangeInfoNotifierProvider
    extends $NotifierProvider<ChangeInfoNotifier, ChangeInfoState> {
  /// 修改群信息 Notifier
  ChangeInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'changeInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$changeInfoNotifierHash();

  @$internal
  @override
  ChangeInfoNotifier create() => ChangeInfoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChangeInfoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChangeInfoState>(value),
    );
  }
}

String _$changeInfoNotifierHash() =>
    r'926a7cd8a916ace8f3a4a3b13f5731841d1acbf9';

/// 修改群信息 Notifier

abstract class _$ChangeInfoNotifier extends $Notifier<ChangeInfoState> {
  ChangeInfoState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChangeInfoState, ChangeInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChangeInfoState, ChangeInfoState>,
              ChangeInfoState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
