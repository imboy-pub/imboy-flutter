// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_member_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 添加群成员 Notifier

@ProviderFor(AddMemberNotifier)
final addMemberProvider = AddMemberNotifierProvider._();

/// 添加群成员 Notifier
final class AddMemberNotifierProvider
    extends $NotifierProvider<AddMemberNotifier, AddMemberState> {
  /// 添加群成员 Notifier
  AddMemberNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addMemberProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addMemberNotifierHash();

  @$internal
  @override
  AddMemberNotifier create() => AddMemberNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddMemberState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddMemberState>(value),
    );
  }
}

String _$addMemberNotifierHash() => r'7cf47ccc8f0a93b35fcb997b7fd4c64cc3da6c58';

/// 添加群成员 Notifier

abstract class _$AddMemberNotifier extends $Notifier<AddMemberState> {
  AddMemberState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AddMemberState, AddMemberState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AddMemberState, AddMemberState>,
              AddMemberState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
