// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dark_model_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DarkModelNotifier)
final darkModelProvider = DarkModelNotifierProvider._();

final class DarkModelNotifierProvider
    extends $NotifierProvider<DarkModelNotifier, DarkModelState> {
  DarkModelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'darkModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$darkModelNotifierHash();

  @$internal
  @override
  DarkModelNotifier create() => DarkModelNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DarkModelState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DarkModelState>(value),
    );
  }
}

String _$darkModelNotifierHash() => r'f50c247eb3226d83a2cefd27b2f0ac22edd93431';

abstract class _$DarkModelNotifier extends $Notifier<DarkModelState> {
  DarkModelState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<DarkModelState, DarkModelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DarkModelState, DarkModelState>,
              DarkModelState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
