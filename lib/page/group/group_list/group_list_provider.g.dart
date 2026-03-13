// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 群组列表 Notifier

@ProviderFor(GroupListNotifier)
final groupListProvider = GroupListNotifierProvider._();

/// 群组列表 Notifier
final class GroupListNotifierProvider
    extends $NotifierProvider<GroupListNotifier, GroupListState> {
  /// 群组列表 Notifier
  GroupListNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupListNotifierHash();

  @$internal
  @override
  GroupListNotifier create() => GroupListNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupListState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupListState>(value),
    );
  }
}

String _$groupListNotifierHash() => r'9307ce79fc7d31592bcbe69e5af3b03b29774d32';

/// 群组列表 Notifier

abstract class _$GroupListNotifier extends $Notifier<GroupListState> {
  GroupListState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<GroupListState, GroupListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GroupListState, GroupListState>,
              GroupListState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
