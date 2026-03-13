// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 消息搜索 Provider

@ProviderFor(MessageSearchNotifier)
final messageSearchProvider = MessageSearchNotifierProvider._();

/// 消息搜索 Provider
final class MessageSearchNotifierProvider
    extends $NotifierProvider<MessageSearchNotifier, MessageSearchState> {
  /// 消息搜索 Provider
  MessageSearchNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageSearchNotifierHash();

  @$internal
  @override
  MessageSearchNotifier create() => MessageSearchNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageSearchState>(value),
    );
  }
}

String _$messageSearchNotifierHash() =>
    r'2efc2a166e9af0c742b7d39d9a73e77a8d8b2c62';

/// 消息搜索 Provider

abstract class _$MessageSearchNotifier extends $Notifier<MessageSearchState> {
  MessageSearchState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MessageSearchState, MessageSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MessageSearchState, MessageSearchState>,
              MessageSearchState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
