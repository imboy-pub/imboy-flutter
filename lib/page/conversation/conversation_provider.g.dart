// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConversationNotifier)
final conversationProvider = ConversationNotifierProvider._();

final class ConversationNotifierProvider
    extends $NotifierProvider<ConversationNotifier, ConversationState> {
  ConversationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationNotifierHash();

  @$internal
  @override
  ConversationNotifier create() => ConversationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationState>(value),
    );
  }
}

String _$conversationNotifierHash() =>
    r'fe0ff3f31de5c7120c1d1544dd0728a72865ffc2';

abstract class _$ConversationNotifier extends $Notifier<ConversationState> {
  ConversationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ConversationState, ConversationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ConversationState, ConversationState>,
              ConversationState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
