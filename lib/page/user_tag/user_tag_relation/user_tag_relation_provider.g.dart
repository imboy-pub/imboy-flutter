// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_tag_relation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserTagRelationNotifier)
final userTagRelationProvider = UserTagRelationNotifierProvider._();

final class UserTagRelationNotifierProvider
    extends $NotifierProvider<UserTagRelationNotifier, UserTagRelationState> {
  UserTagRelationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userTagRelationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userTagRelationNotifierHash();

  @$internal
  @override
  UserTagRelationNotifier create() => UserTagRelationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserTagRelationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserTagRelationState>(value),
    );
  }
}

String _$userTagRelationNotifierHash() =>
    r'6d73c107c388b8003fcb73995a45f12f543b2ce8';

abstract class _$UserTagRelationNotifier
    extends $Notifier<UserTagRelationState> {
  UserTagRelationState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UserTagRelationState, UserTagRelationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserTagRelationState, UserTagRelationState>,
              UserTagRelationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
