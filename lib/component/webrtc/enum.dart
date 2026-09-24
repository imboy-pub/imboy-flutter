import 'dart:core';

enum WebRTCCallState {
  callStateNew,
  callStateRinging,
  callStateInvite,

  /// 被叫已接听（answer 信令到达，主叫侧专用）。
  /// LK-APP-01：LiveKit 模式下这是主叫发起 joinRoom 接入媒体房的触发点——
  /// accept 前主叫保持纯信令等待，不连 Room、不发布媒体。
  callStateAnswered,
  callStateConnected,
  callStateBye,
  callStateBusy,

  /// 网络/媒体异常中断（LiveKit Room 断开且非本端挂断等）。
  /// 与 callStateBye 区分：bye 是对端主动挂断，failed 是链路故障，
  /// 两者对应的提示文案与本地通话记录状态码都不同。
  callStateFailed,
}
