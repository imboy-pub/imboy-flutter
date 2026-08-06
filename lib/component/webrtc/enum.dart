import 'dart:core';

enum WebRTCCallState {
  callStateNew,
  callStateRinging,
  callStateInvite,
  callStateConnected,
  callStateBye,
  callStateBusy,

  /// 网络/媒体异常中断（ICE 重启次数耗尽等）。
  /// 与 callStateBye 区分：bye 是对端主动挂断，failed 是链路故障，
  /// 两者对应的提示文案与本地通话记录状态码都不同。
  callStateFailed,
}

enum VideoSource { camera, screen }
