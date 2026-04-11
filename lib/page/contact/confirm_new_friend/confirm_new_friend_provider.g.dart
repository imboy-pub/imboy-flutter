// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_new_friend_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 确认新好友 Notifier

@ProviderFor(ConfirmNewFriendNotifier)
final confirmNewFriendProvider = ConfirmNewFriendNotifierProvider._();

/// 确认新好友 Notifier
final class ConfirmNewFriendNotifierProvider
    extends $NotifierProvider<ConfirmNewFriendNotifier, ConfirmNewFriendState> {
  /// 确认新好友 Notifier
  ConfirmNewFriendNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'confirmNewFriendProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$confirmNewFriendNotifierHash();

  @$internal
  @override
  ConfirmNewFriendNotifier create() => ConfirmNewFriendNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConfirmNewFriendState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConfirmNewFriendState>(value),
    );
  }
}

String _$confirmNewFriendNotifierHash() =>
    r'2972fd7e14bdd7d8380659d9bb4cf781907c053d';

/// 确认新好友 Notifier

abstract class _$ConfirmNewFriendNotifier
    extends $Notifier<ConfirmNewFriendState> {
  ConfirmNewFriendState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ConfirmNewFriendState, ConfirmNewFriendState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConfirmNewFriendState, ConfirmNewFriendState>,
              ConfirmNewFriendState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
