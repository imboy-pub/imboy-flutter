// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'help_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HelpNotifier)
final helpProvider = HelpNotifierProvider._();

final class HelpNotifierProvider
    extends $NotifierProvider<HelpNotifier, HelpState> {
  HelpNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helpProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helpNotifierHash();

  @$internal
  @override
  HelpNotifier create() => HelpNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HelpState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HelpState>(value),
    );
  }
}

String _$helpNotifierHash() => r'24cbaf0696f2bc2ba7dffe32b0eeaa239b26a38a';

abstract class _$HelpNotifier extends $Notifier<HelpState> {
  HelpState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<HelpState, HelpState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HelpState, HelpState>,
              HelpState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
