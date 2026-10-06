// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'p2p_call_screen_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// P2P Call Screen Provider
///
/// LK-APP-01：媒体面迁移 LiveKit SFU（与群通话 rtc_room_provider 同一模式）。
/// 信令（邀请/响铃/接听/拒接/挂断）、状态机、悬浮窗 UX 全部保留原有实现；
/// offer/answer 信令退化为“邀请/接听”通知（payload 仅 media，无 SDP），
/// ICE candidate 彻底消失——媒体协商由 SFU 完成。

@ProviderFor(P2pCallScreenNotifier)
final p2pCallScreenProvider = P2pCallScreenNotifierProvider._();

/// P2P Call Screen Provider
///
/// LK-APP-01：媒体面迁移 LiveKit SFU（与群通话 rtc_room_provider 同一模式）。
/// 信令（邀请/响铃/接听/拒接/挂断）、状态机、悬浮窗 UX 全部保留原有实现；
/// offer/answer 信令退化为“邀请/接听”通知（payload 仅 media，无 SDP），
/// ICE candidate 彻底消失——媒体协商由 SFU 完成。
final class P2pCallScreenNotifierProvider
    extends $NotifierProvider<P2pCallScreenNotifier, P2pCallScreenState> {
  /// P2P Call Screen Provider
  ///
  /// LK-APP-01：媒体面迁移 LiveKit SFU（与群通话 rtc_room_provider 同一模式）。
  /// 信令（邀请/响铃/接听/拒接/挂断）、状态机、悬浮窗 UX 全部保留原有实现；
  /// offer/answer 信令退化为“邀请/接听”通知（payload 仅 media，无 SDP），
  /// ICE candidate 彻底消失——媒体协商由 SFU 完成。
  P2pCallScreenNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'p2pCallScreenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$p2pCallScreenNotifierHash();

  @$internal
  @override
  P2pCallScreenNotifier create() => P2pCallScreenNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(P2pCallScreenState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<P2pCallScreenState>(value),
    );
  }
}

String _$p2pCallScreenNotifierHash() =>
    r'578c6a2f8a674b64fdb743a8ac0d5af5797dc29a';

/// P2P Call Screen Provider
///
/// LK-APP-01：媒体面迁移 LiveKit SFU（与群通话 rtc_room_provider 同一模式）。
/// 信令（邀请/响铃/接听/拒接/挂断）、状态机、悬浮窗 UX 全部保留原有实现；
/// offer/answer 信令退化为“邀请/接听”通知（payload 仅 media，无 SDP），
/// ICE candidate 彻底消失——媒体协商由 SFU 完成。

abstract class _$P2pCallScreenNotifier extends $Notifier<P2pCallScreenState> {
  P2pCallScreenState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<P2pCallScreenState, P2pCallScreenState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<P2pCallScreenState, P2pCallScreenState>,
              P2pCallScreenState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
