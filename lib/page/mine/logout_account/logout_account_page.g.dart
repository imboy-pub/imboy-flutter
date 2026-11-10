// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logout_account_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LogoutAccountNotifier)
final logoutAccountProvider = LogoutAccountNotifierProvider._();

final class LogoutAccountNotifierProvider
    extends $NotifierProvider<LogoutAccountNotifier, LogoutAccountState> {
  LogoutAccountNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logoutAccountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logoutAccountNotifierHash();

  @$internal
  @override
  LogoutAccountNotifier create() => LogoutAccountNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogoutAccountState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogoutAccountState>(value),
    );
  }
}

String _$logoutAccountNotifierHash() =>
    r'5908a8ca41d6ac28c4c5bb3834b3ee0f3829ce33';

abstract class _$LogoutAccountNotifier extends $Notifier<LogoutAccountState> {
  LogoutAccountState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LogoutAccountState, LogoutAccountState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LogoutAccountState, LogoutAccountState>,
              LogoutAccountState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
