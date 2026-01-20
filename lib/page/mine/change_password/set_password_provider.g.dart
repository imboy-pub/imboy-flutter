// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_password_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 设置密码页面状态管理

@ProviderFor(SetPassword)
final setPasswordProvider = SetPasswordProvider._();

/// 设置密码页面状态管理
final class SetPasswordProvider
    extends $NotifierProvider<SetPassword, SetPasswordState> {
  /// 设置密码页面状态管理
  SetPasswordProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setPasswordProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setPasswordHash();

  @$internal
  @override
  SetPassword create() => SetPassword();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetPasswordState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetPasswordState>(value),
    );
  }
}

String _$setPasswordHash() => r'1f32403dfac92ba5bf8436f5355bdf01d43ef5e3';

/// 设置密码页面状态管理

abstract class _$SetPassword extends $Notifier<SetPasswordState> {
  SetPasswordState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SetPasswordState, SetPasswordState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SetPasswordState, SetPasswordState>,
              SetPasswordState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
