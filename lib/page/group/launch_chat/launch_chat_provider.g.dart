// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'launch_chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 发起聊天 Notifier

@ProviderFor(LaunchChatNotifier)
final launchChatProvider = LaunchChatNotifierProvider._();

/// 发起聊天 Notifier
final class LaunchChatNotifierProvider
    extends $NotifierProvider<LaunchChatNotifier, LaunchChatState> {
  /// 发起聊天 Notifier
  LaunchChatNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'launchChatProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$launchChatNotifierHash();

  @$internal
  @override
  LaunchChatNotifier create() => LaunchChatNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LaunchChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LaunchChatState>(value),
    );
  }
}

String _$launchChatNotifierHash() =>
    r'0feed426120d9fe481618fe0a6d15d62406b858a';

/// 发起聊天 Notifier

abstract class _$LaunchChatNotifier extends $Notifier<LaunchChatState> {
  LaunchChatState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LaunchChatState, LaunchChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LaunchChatState, LaunchChatState>,
              LaunchChatState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
