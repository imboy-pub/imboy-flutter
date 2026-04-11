// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeedbackPageNotifier)
final feedbackPageProvider = FeedbackPageNotifierProvider._();

final class FeedbackPageNotifierProvider
    extends $NotifierProvider<FeedbackPageNotifier, FeedbackPageState> {
  FeedbackPageNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedbackPageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedbackPageNotifierHash();

  @$internal
  @override
  FeedbackPageNotifier create() => FeedbackPageNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedbackPageState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedbackPageState>(value),
    );
  }
}

String _$feedbackPageNotifierHash() =>
    r'3e07b43506c59cd40b2b1cd81699493fb733a648';

abstract class _$FeedbackPageNotifier extends $Notifier<FeedbackPageState> {
  FeedbackPageState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FeedbackPageState, FeedbackPageState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FeedbackPageState, FeedbackPageState>,
              FeedbackPageState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
