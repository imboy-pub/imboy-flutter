// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 个人信息 Provider

@ProviderFor(PersonalInfoNotifier)
final personalInfoProvider = PersonalInfoNotifierProvider._();

/// 个人信息 Provider
final class PersonalInfoNotifierProvider
    extends $NotifierProvider<PersonalInfoNotifier, PersonalInfoState> {
  /// 个人信息 Provider
  PersonalInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalInfoNotifierHash();

  @$internal
  @override
  PersonalInfoNotifier create() => PersonalInfoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PersonalInfoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PersonalInfoState>(value),
    );
  }
}

String _$personalInfoNotifierHash() =>
    r'19add9c3875993d2f11073938ed3dbac79fb6db1';

/// 个人信息 Provider

abstract class _$PersonalInfoNotifier extends $Notifier<PersonalInfoState> {
  PersonalInfoState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PersonalInfoState, PersonalInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PersonalInfoState, PersonalInfoState>,
              PersonalInfoState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
