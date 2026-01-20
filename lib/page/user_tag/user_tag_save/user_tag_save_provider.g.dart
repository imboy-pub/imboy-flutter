// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_tag_save_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserTagSaveNotifier)
final userTagSaveProvider = UserTagSaveNotifierProvider._();

final class UserTagSaveNotifierProvider
    extends $NotifierProvider<UserTagSaveNotifier, UserTagSaveState> {
  UserTagSaveNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userTagSaveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userTagSaveNotifierHash();

  @$internal
  @override
  UserTagSaveNotifier create() => UserTagSaveNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserTagSaveState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserTagSaveState>(value),
    );
  }
}

String _$userTagSaveNotifierHash() =>
    r'2eaba1f17f1f3bbce5c92e3a3ff28d72cd9e39f3';

abstract class _$UserTagSaveNotifier extends $Notifier<UserTagSaveState> {
  UserTagSaveState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<UserTagSaveState, UserTagSaveState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserTagSaveState, UserTagSaveState>,
              UserTagSaveState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
