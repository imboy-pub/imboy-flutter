// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_select_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 群组选择 Notifier

@ProviderFor(GroupSelectNotifier)
final groupSelectProvider = GroupSelectNotifierProvider._();

/// 群组选择 Notifier
final class GroupSelectNotifierProvider
    extends $NotifierProvider<GroupSelectNotifier, GroupSelectState> {
  /// 群组选择 Notifier
  GroupSelectNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupSelectProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupSelectNotifierHash();

  @$internal
  @override
  GroupSelectNotifier create() => GroupSelectNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupSelectState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupSelectState>(value),
    );
  }
}

String _$groupSelectNotifierHash() =>
    r'a5c48dadac29674f96c0e1625b5e21ab2d9849f0';

/// 群组选择 Notifier

abstract class _$GroupSelectNotifier extends $Notifier<GroupSelectState> {
  GroupSelectState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<GroupSelectState, GroupSelectState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GroupSelectState, GroupSelectState>,
              GroupSelectState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
