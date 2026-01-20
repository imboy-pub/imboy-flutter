// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_password_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 修改登录密码页面状态管理

@ProviderFor(ChangeLoginPassword)
final changeLoginPasswordProvider = ChangeLoginPasswordProvider._();

/// 修改登录密码页面状态管理
final class ChangeLoginPasswordProvider
    extends $NotifierProvider<ChangeLoginPassword, ChangeLoginPasswordState> {
  /// 修改登录密码页面状态管理
  ChangeLoginPasswordProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'changeLoginPasswordProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$changeLoginPasswordHash();

  @$internal
  @override
  ChangeLoginPassword create() => ChangeLoginPassword();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChangeLoginPasswordState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChangeLoginPasswordState>(value),
    );
  }
}

String _$changeLoginPasswordHash() =>
    r'aed456932b987a2c76fbd57c1f0a928124cb0b7a';

/// 修改登录密码页面状态管理

abstract class _$ChangeLoginPassword
    extends $Notifier<ChangeLoginPasswordState> {
  ChangeLoginPasswordState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<ChangeLoginPasswordState, ChangeLoginPasswordState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChangeLoginPasswordState, ChangeLoginPasswordState>,
              ChangeLoginPasswordState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
