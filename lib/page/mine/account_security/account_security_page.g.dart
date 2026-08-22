// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_security_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AccountSecurity 模块的状态

@ProviderFor(AccountSecurityNotifier)
final accountSecurityProvider = AccountSecurityNotifierProvider._();

/// AccountSecurity 模块的状态
final class AccountSecurityNotifierProvider
    extends $NotifierProvider<AccountSecurityNotifier, int> {
  /// AccountSecurity 模块的状态
  AccountSecurityNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountSecurityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountSecurityNotifierHash();

  @$internal
  @override
  AccountSecurityNotifier create() => AccountSecurityNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$accountSecurityNotifierHash() =>
    r'd3ad9ca7406f33d322cb8274c50ac2ea88a2dedb';

/// AccountSecurity 模块的状态

abstract class _$AccountSecurityNotifier extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
