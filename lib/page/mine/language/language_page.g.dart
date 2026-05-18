// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LanguageNotifier)
final languageProvider = LanguageNotifierProvider._();

final class LanguageNotifierProvider
    extends $NotifierProvider<LanguageNotifier, LanguageState> {
  LanguageNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'languageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$languageNotifierHash();

  @$internal
  @override
  LanguageNotifier create() => LanguageNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LanguageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LanguageState>(value),
    );
  }
}

String _$languageNotifierHash() => r'aea57570ae345a3918726c8de9a486c2218eb47b';

abstract class _$LanguageNotifier extends $Notifier<LanguageState> {
  LanguageState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LanguageState, LanguageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LanguageState, LanguageState>,
              LanguageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
