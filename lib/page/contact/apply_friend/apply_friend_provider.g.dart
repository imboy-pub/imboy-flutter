// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apply_friend_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 申请好友 Notifier

@ProviderFor(ApplyFriendNotifier)
final applyFriendProvider = ApplyFriendNotifierProvider._();

/// 申请好友 Notifier
final class ApplyFriendNotifierProvider
    extends $NotifierProvider<ApplyFriendNotifier, ApplyFriendState> {
  /// 申请好友 Notifier
  ApplyFriendNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'applyFriendProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$applyFriendNotifierHash();

  @$internal
  @override
  ApplyFriendNotifier create() => ApplyFriendNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApplyFriendState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApplyFriendState>(value),
    );
  }
}

String _$applyFriendNotifierHash() =>
    r'7762d75e5293454797a675f6846785d3a99f8d77';

/// 申请好友 Notifier

abstract class _$ApplyFriendNotifier extends $Notifier<ApplyFriendState> {
  ApplyFriendState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ApplyFriendState, ApplyFriendState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ApplyFriendState, ApplyFriendState>,
              ApplyFriendState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
