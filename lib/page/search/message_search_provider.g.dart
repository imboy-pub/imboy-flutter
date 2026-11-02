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
    r'067238e50f22624a136599db1222d14b64caa894';

/// 消息搜索 Provider

abstract class _$MessageSearchNotifier extends $Notifier<MessageSearchState> {
  MessageSearchState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MessageSearchState, MessageSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MessageSearchState, MessageSearchState>,
              MessageSearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
