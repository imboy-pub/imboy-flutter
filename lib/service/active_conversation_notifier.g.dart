// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_conversation_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 活跃会话管理器（全局单例）
///
/// 用于跟踪用户当前正在查看的会话，以便正确计算未读数
/// - 当用户进入聊天页面时，设置活跃会话
/// - 当用户离开聊天页面时，清除活跃会话
/// - 5分钟内的会话视为活跃

@ProviderFor(ActiveConversationNotifier)
final activeConversationProvider = ActiveConversationNotifierProvider._();

/// 活跃会话管理器（全局单例）
///
/// 用于跟踪用户当前正在查看的会话，以便正确计算未读数
/// - 当用户进入聊天页面时，设置活跃会话
/// - 当用户离开聊天页面时，清除活跃会话
/// - 5分钟内的会话视为活跃
final class ActiveConversationNotifierProvider
    extends
        $NotifierProvider<ActiveConversationNotifier, ActiveConversationState> {
  /// 活跃会话管理器（全局单例）
  ///
  /// 用于跟踪用户当前正在查看的会话，以便正确计算未读数
  /// - 当用户进入聊天页面时，设置活跃会话
  /// - 当用户离开聊天页面时，清除活跃会话
  /// - 5分钟内的会话视为活跃
  ActiveConversationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeConversationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeConversationNotifierHash();

  @$internal
  @override
  ActiveConversationNotifier create() => ActiveConversationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveConversationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveConversationState>(value),
    );
  }
}

String _$activeConversationNotifierHash() =>
    r'cc522256dd95fca601a489258044f05a68704b66';

/// 活跃会话管理器（全局单例）
///
/// 用于跟踪用户当前正在查看的会话，以便正确计算未读数
/// - 当用户进入聊天页面时，设置活跃会话
/// - 当用户离开聊天页面时，清除活跃会话
/// - 5分钟内的会话视为活跃

abstract class _$ActiveConversationNotifier
    extends $Notifier<ActiveConversationState> {
  ActiveConversationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<ActiveConversationState, ActiveConversationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ActiveConversationState, ActiveConversationState>,
              ActiveConversationState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
