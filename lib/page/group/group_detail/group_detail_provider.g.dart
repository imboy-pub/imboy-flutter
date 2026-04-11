// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 群组详情 Notifier

@ProviderFor(GroupDetailNotifier)
final groupDetailProvider = GroupDetailNotifierProvider._();

/// 群组详情 Notifier
final class GroupDetailNotifierProvider
    extends $NotifierProvider<GroupDetailNotifier, GroupDetailState> {
  /// 群组详情 Notifier
  GroupDetailNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupDetailProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupDetailNotifierHash();

  @$internal
  @override
  GroupDetailNotifier create() => GroupDetailNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupDetailState>(value),
    );
  }
}

String _$groupDetailNotifierHash() =>
    r'f8faefbb2481035a5e52d3142d25c11c8cccc168';

/// 群组详情 Notifier

abstract class _$GroupDetailNotifier extends $Notifier<GroupDetailState> {
  GroupDetailState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<GroupDetailState, GroupDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GroupDetailState, GroupDetailState>,
              GroupDetailState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
