// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_member_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 群成员详情 Notifier

@ProviderFor(GroupMemberDetailNotifier)
final groupMemberDetailProvider = GroupMemberDetailNotifierProvider._();

/// 群成员详情 Notifier
final class GroupMemberDetailNotifierProvider
    extends $NotifierProvider<GroupMemberDetailNotifier, GroupMemberDetailState> {
  /// 群成员详情 Notifier
  GroupMemberDetailNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupMemberDetailProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupMemberDetailNotifierHash();

  @$internal
  @override
  GroupMemberDetailNotifier create() => GroupMemberDetailNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupMemberDetailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupMemberDetailState>(value),
    );
  }
}

String _$groupMemberDetailNotifierHash() =>
    r'abc123def456789012345678901234567890abcd';

/// 群成员详情 Notifier

abstract class _$GroupMemberDetailNotifier extends $Notifier<GroupMemberDetailState> {
  GroupMemberDetailState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<GroupMemberDetailState, GroupMemberDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GroupMemberDetailState, GroupMemberDetailState>,
              GroupMemberDetailState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
