// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bind_email_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BindEmailNotifier)
final bindEmailProvider = BindEmailNotifierProvider._();

final class BindEmailNotifierProvider
    extends $NotifierProvider<BindEmailNotifier, BindEmailState> {
  BindEmailNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bindEmailProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bindEmailNotifierHash();

  @$internal
  @override
  BindEmailNotifier create() => BindEmailNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BindEmailState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BindEmailState>(value),
    );
  }
}

String _$bindEmailNotifierHash() => r'dea0ef72f9c10f24790008875f97091bb0f636bb';

abstract class _$BindEmailNotifier extends $Notifier<BindEmailState> {
  BindEmailState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<BindEmailState, BindEmailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BindEmailState, BindEmailState>,
              BindEmailState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
