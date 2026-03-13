// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'people_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PeopleInfoNotifier)
final peopleInfoProvider = PeopleInfoNotifierProvider._();

final class PeopleInfoNotifierProvider
    extends $NotifierProvider<PeopleInfoNotifier, PeopleInfoState> {
  PeopleInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'peopleInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$peopleInfoNotifierHash();

  @$internal
  @override
  PeopleInfoNotifier create() => PeopleInfoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PeopleInfoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PeopleInfoState>(value),
    );
  }
}

String _$peopleInfoNotifierHash() =>
    r'90f0d0c745ca96d7ba81550ecafb165b8e67e4be';

abstract class _$PeopleInfoNotifier extends $Notifier<PeopleInfoState> {
  PeopleInfoState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PeopleInfoState, PeopleInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PeopleInfoState, PeopleInfoState>,
              PeopleInfoState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(userId)
final userIdProvider = UserIdProvider._();

final class UserIdProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  UserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userIdHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return userId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$userIdHash() => r'd55319be587f2e50f858a927887bd91cfc02cf95';
