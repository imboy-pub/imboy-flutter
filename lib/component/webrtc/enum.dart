import 'dart:core';

enum WebRTCCallState {
  callStateNew,
  callStateRinging,
  callStateInvite,
  callStateConnected,
  callStateBye,
  callStateBusy,
}

enum VideoSource { camera, screen }
