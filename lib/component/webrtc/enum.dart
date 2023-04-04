import 'dart:core';

enum WebRTCCallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  CallStateBusy,
}

enum VideoSource {
  Camera,
  Screen,
}
