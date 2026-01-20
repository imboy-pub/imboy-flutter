// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_nickname_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 设置昵称 Provider

@ProviderFor(SetNicknameNotifier)
final setNicknameProvider = SetNicknameNotifierProvider._();

/// 设置昵称 Provider
final class SetNicknameNotifierProvider
    extends $NotifierProvider<SetNicknameNotifier, SetNicknameState> {
  /// 设置昵称 Provider
  SetNicknameNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'setNicknameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$setNicknameNotifierHash();

  @$internal
  @override
  SetNicknameNotifier create() => SetNicknameNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SetNicknameState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SetNicknameState>(value),
    );
  }
}

String _$setNicknameNotifierHash() =>
    r'45919280ccfa1dd4cb180f6be0c19c186b4ea61c';

/// 设置昵称 Provider

abstract class _$SetNicknameNotifier extends $Notifier<SetNicknameState> {
  SetNicknameState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SetNicknameState, SetNicknameState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SetNicknameState, SetNicknameState>,
              SetNicknameState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
