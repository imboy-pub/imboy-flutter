// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_collect_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// UserCollect Notifier
/// 处理收藏相关的业务逻辑

@ProviderFor(UserCollectNotifier)
final userCollectProvider = UserCollectNotifierProvider._();

/// UserCollect Notifier
/// 处理收藏相关的业务逻辑
final class UserCollectNotifierProvider
    extends $NotifierProvider<UserCollectNotifier, UserCollectState> {
  /// UserCollect Notifier
  /// 处理收藏相关的业务逻辑
  UserCollectNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userCollectProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userCollectNotifierHash();

  @$internal
  @override
  UserCollectNotifier create() => UserCollectNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserCollectState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserCollectState>(value),
    );
  }
}

String _$userCollectNotifierHash() =>
    r'6f430ab1208f3e12672d80148dd5ffa35f780640';

/// UserCollect Notifier
/// 处理收藏相关的业务逻辑

abstract class _$UserCollectNotifier extends $Notifier<UserCollectState> {
  UserCollectState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<UserCollectState, UserCollectState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserCollectState, UserCollectState>,
              UserCollectState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
