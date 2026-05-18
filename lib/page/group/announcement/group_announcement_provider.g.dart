// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_announcement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 群组公告 Notifier

@ProviderFor(GroupAnnouncementNotifier)
final groupAnnouncementProvider = GroupAnnouncementNotifierFamily._();

/// 群组公告 Notifier
final class GroupAnnouncementNotifierProvider
    extends
        $NotifierProvider<GroupAnnouncementNotifier, GroupAnnouncementState> {
  /// 群组公告 Notifier
  GroupAnnouncementNotifierProvider._({
    required GroupAnnouncementNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupAnnouncementProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupAnnouncementNotifierHash();

  @override
  String toString() {
    return r'groupAnnouncementProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GroupAnnouncementNotifier create() => GroupAnnouncementNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupAnnouncementState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupAnnouncementState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GroupAnnouncementNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupAnnouncementNotifierHash() =>
    r'c06ba424b67f27448e9d27f6e3caccda0d78a6e5';

/// 群组公告 Notifier

final class GroupAnnouncementNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GroupAnnouncementNotifier,
          GroupAnnouncementState,
          GroupAnnouncementState,
          GroupAnnouncementState,
          String
        > {
  GroupAnnouncementNotifierFamily._()
    : super(
        retry: null,
        name: r'groupAnnouncementProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 群组公告 Notifier

  GroupAnnouncementNotifierProvider call(String groupId) =>
      GroupAnnouncementNotifierProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupAnnouncementProvider';
}

/// 群组公告 Notifier

abstract class _$GroupAnnouncementNotifier
    extends $Notifier<GroupAnnouncementState> {
  late final _$args = ref.$arg as String;
  String get groupId => _$args;

  GroupAnnouncementState build(String groupId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<GroupAnnouncementState, GroupAnnouncementState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GroupAnnouncementState, GroupAnnouncementState>,
              GroupAnnouncementState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
