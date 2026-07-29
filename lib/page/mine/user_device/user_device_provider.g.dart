// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_device_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserDeviceNotifier)
final userDeviceProvider = UserDeviceNotifierProvider._();

final class UserDeviceNotifierProvider
    extends $NotifierProvider<UserDeviceNotifier, UserDeviceState> {
  UserDeviceNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDeviceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDeviceNotifierHash();

  @$internal
  @override
  UserDeviceNotifier create() => UserDeviceNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserDeviceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserDeviceState>(value),
    );
  }
}

String _$userDeviceNotifierHash() =>
    r'd4fb8c205b6f28b23442835c462f659d643c4d37';

abstract class _$UserDeviceNotifier extends $Notifier<UserDeviceState> {
  UserDeviceState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<UserDeviceState, UserDeviceState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserDeviceState, UserDeviceState>,
              UserDeviceState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
