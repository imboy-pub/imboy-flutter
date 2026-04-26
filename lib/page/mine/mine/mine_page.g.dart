// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mine_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MineNotifier)
final mineProvider = MineNotifierProvider._();

final class MineNotifierProvider
    extends $NotifierProvider<MineNotifier, MineState> {
  MineNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mineNotifierHash();

  @$internal
  @override
  MineNotifier create() => MineNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MineState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MineState>(value),
    );
  }
}

String _$mineNotifierHash() => r'6f0600f98906b53b6c72e877f13176b90e0ec69a';

abstract class _$MineNotifier extends $Notifier<MineState> {
  MineState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MineState, MineState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MineState, MineState>,
              MineState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
