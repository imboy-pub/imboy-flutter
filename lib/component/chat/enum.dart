/// All possible message types.
library;

enum CustomMessageType {
  text,
  textStream,
  image,
  file,
  location,
  audio,
  video,
  unsupported,
  system,
  custom,
  //
  // webrtc 音频消息
  webrtcAudio,
  // webrtc 视频消息
  webrtcVideo,
  // 引用消息
  quote,
}

// 在文件任意位置添加 ↓
enum ExtraItemType { image, file, camera, voice, video, none }

/// Used to toggle the visibility behavior of the [SendButton] based on the
/// [TextField] state inside the [Input] widget.
enum SendButtonVisibilityMode {
  /// Always show the [SendButton] regardless of the [TextField] state.
  always,

  /// The [SendButton] will only appear when the [TextField] is not empty.
  editing,

  /// Always hide the [SendButton] regardless of the [TextField] state.
  hidden,
}
