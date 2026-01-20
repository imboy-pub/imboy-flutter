// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_size_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FontSizeNotifier)
final fontSizeProvider = FontSizeNotifierProvider._();

final class FontSizeNotifierProvider
    extends $NotifierProvider<FontSizeNotifier, FontSizeState> {
  FontSizeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontSizeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontSizeNotifierHash();

  @$internal
  @override
  FontSizeNotifier create() => FontSizeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FontSizeState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FontSizeState>(value),
    );
  }
}

String _$fontSizeNotifierHash() => r'58698b5f670e92b678e286ca6c887a11c47a3267';

abstract class _$FontSizeNotifier extends $Notifier<FontSizeState> {
  FontSizeState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FontSizeState, FontSizeState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FontSizeState, FontSizeState>,
              FontSizeState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
