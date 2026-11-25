// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Search Provider - 使用 @riverpod 注解

@ProviderFor(SearchNotifier)
final searchProvider = SearchNotifierProvider._();

/// Search Provider - 使用 @riverpod 注解
final class SearchNotifierProvider
    extends $NotifierProvider<SearchNotifier, SearchDataState> {
  /// Search Provider - 使用 @riverpod 注解
  SearchNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchNotifierHash();

  @$internal
  @override
  SearchNotifier create() => SearchNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchDataState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchDataState>(value),
    );
  }
}

String _$searchNotifierHash() => r'7cad4408f540a1a101d401419fe5aa466de49418';

/// Search Provider - 使用 @riverpod 注解

abstract class _$SearchNotifier extends $Notifier<SearchDataState> {
  SearchDataState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SearchDataState, SearchDataState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SearchDataState, SearchDataState>,
              SearchDataState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
