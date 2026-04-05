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
    r'9c2abdd386fac38be310ddec9a665069e177cb54';

abstract class _$UserTagRelationNotifier
    extends $Notifier<UserTagRelationState> {
  UserTagRelationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<UserTagRelationState, UserTagRelationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserTagRelationState, UserTagRelationState>,
              UserTagRelationState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
