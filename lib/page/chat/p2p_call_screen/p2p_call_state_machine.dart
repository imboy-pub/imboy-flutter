/// P2P 通话状态机（纯逻辑）
///
/// 通话页原来把「阶段」隐含在若干个布尔量与一条自由文本 `stateTips` 里，
/// 接通后没人把 `stateTips` 清空，于是音频通话全程停在“响铃中”而看不到时长；
/// 结束原因也散在四个 switch 分支里各自拍一个 `CallStateCode`。
///
/// 这里把「阶段 + 结束原因」收敛成一个不可变值，信令与本地事件统一经
/// [CallStatus.apply] 驱动。本文件**不依赖 Flutter、不依赖 i18n**，
/// 文案只给出 [CallTipKey]，由页面翻译——这样四条路径可以纯单测。
library;

import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';

/// 通话生命周期阶段。
enum CallPhase {
  /// 已发起呼叫，尚未收到对端响铃。
  dialing,

  /// 对端已响铃，等待接听。
  ringing,

  /// 媒体已接通。
  connected,

  /// 已结束（终态，吸收后续信令）。
  ended,
}

/// 驱动状态机的信令 / 本地事件。
enum CallSignal {
  /// 收到对端 `ringing`。
  ringing,

  /// SDP answer 到达 / 远端轨道到达 / ICE 连通。
  connected,

  /// 对端挂断（`bye`）。
  peerBye,

  /// 对端忙或拒接（`busy`）。
  peerBusy,

  /// 本机应答超时（[CallTimeoutConfig.answerTimeout]）。
  answerTimeout,

  /// 本机点击挂断。
  localHangUp,

  /// 网络 / 媒体异常中断（ICE 重启耗尽等）。
  failed,
}

/// 结束原因。仅在 [CallPhase.ended] 有意义。
enum CallEndReason { none, peerHangUp, peerBusy, noAnswer, localHangUp, failed }

/// 状态文案键。页面负责映射到 i18n，逻辑层保持零依赖。
enum CallTipKey {
  /// 无提示：接通中显示通话时长，未接通显示“通话中”占位。
  none,
  waitingPeerAccept,
  ringing,
  peerNoResponse,
  peerHungUp,
  busy,
  networkError,
  callEnded,
}

/// 通话状态快照（不可变）。
class CallStatus {
  const CallStatus({
    this.phase = CallPhase.dialing,
    this.endReason = CallEndReason.none,
    this.wasConnected = false,
  });

  final CallPhase phase;
  final CallEndReason endReason;

  /// 结束前是否曾接通 —— 决定本地通话记录写「通话时长」还是「未接通」。
  final bool wasConnected;

  bool get isTerminal => phase == CallPhase.ended;

  /// 接通中才展示通话时长（未接通时时长恒为 00:00，展示出来是误导）。
  bool get showsDuration => phase == CallPhase.connected;

  CallStatus apply(CallSignal signal) {
    // 终态吸收：结束后迟到的 bye / busy / 超时不得再改写结束原因。
    if (isTerminal) return this;

    switch (signal) {
      case CallSignal.ringing:
        // 接通后迟到的 ringing 不得把阶段拉回响铃。
        return phase == CallPhase.dialing
            ? const CallStatus(phase: CallPhase.ringing)
            : this;

      case CallSignal.connected:
        return const CallStatus(phase: CallPhase.connected, wasConnected: true);

      case CallSignal.answerTimeout:
        // 接通后应答定时器若漏关，不得误杀正在进行的通话。
        if (phase == CallPhase.connected) return this;
        return _end(CallEndReason.noAnswer);

      case CallSignal.peerBusy:
        if (phase == CallPhase.connected) return this;
        return _end(CallEndReason.peerBusy);

      case CallSignal.peerBye:
        return _end(CallEndReason.peerHangUp);

      case CallSignal.localHangUp:
        return _end(CallEndReason.localHangUp);

      case CallSignal.failed:
        return _end(CallEndReason.failed);
    }
  }

  CallStatus _end(CallEndReason reason) => CallStatus(
    phase: CallPhase.ended,
    endReason: reason,
    wasConnected: wasConnected,
  );

  CallTipKey get tipKey => switch (phase) {
    CallPhase.dialing => CallTipKey.waitingPeerAccept,
    CallPhase.ringing => CallTipKey.ringing,
    CallPhase.connected => CallTipKey.none,
    CallPhase.ended => switch (endReason) {
      CallEndReason.noAnswer => CallTipKey.peerNoResponse,
      CallEndReason.peerHangUp => CallTipKey.peerHungUp,
      CallEndReason.peerBusy => CallTipKey.busy,
      CallEndReason.failed => CallTipKey.networkError,
      CallEndReason.localHangUp || CallEndReason.none => CallTipKey.callEnded,
    },
  };

  /// 写入本地通话记录的状态码（见 [CallStateCode]）。
  /// 未结束返回 [CallStateCode.calling]（0），调用方据此跳过写库。
  int get recordStateCode {
    if (!isTerminal) return CallStateCode.calling;
    // 曾接通过：无论谁挂断都是一通有效通话，记 connected 才能渲染通话时长。
    if (wasConnected) return CallStateCode.connected;
    return switch (endReason) {
      CallEndReason.noAnswer => CallStateCode.rejected,
      CallEndReason.peerHangUp => CallStateCode.peerHungUp,
      CallEndReason.localHangUp => CallStateCode.localHungUp,
      CallEndReason.peerBusy => CallStateCode.busy,
      CallEndReason.failed => CallStateCode.failed,
      CallEndReason.none => CallStateCode.calling,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CallStatus &&
      other.phase == phase &&
      other.endReason == endReason &&
      other.wasConnected == wasConnected;

  @override
  int get hashCode => Object.hash(phase, endReason, wasConnected);

  @override
  String toString() =>
      'CallStatus($phase, $endReason, wasConnected: $wasConnected)';
}
