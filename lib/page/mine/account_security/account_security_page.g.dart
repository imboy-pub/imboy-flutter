// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_security_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AccountSecurityNotifier)
final accountSecurityProvider = AccountSecurityNotifierProvider._();

final class AccountSecurityNotifierProvider
    extends $NotifierProvider<AccountSecurityNotifier, AccountSecurityState> {
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
  Override overrideWithValue(AccountSecurityState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountSecurityState>(value),
    );
  }
}

String _$accountSecurityNotifierHash() =>
    r'58bb23e4a734f7329ad5fe1fc58c75a9ef42db5a';

abstract class _$AccountSecurityNotifier
    extends $Notifier<AccountSecurityState> {
  AccountSecurityState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AccountSecurityState, AccountSecurityState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AccountSecurityState, AccountSecurityState>,
              AccountSecurityState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
