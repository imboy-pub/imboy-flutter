// 条件导入：移动端使用完整的 audio_waveforms 组件
// Web 平台使用 message_audio_builder_stub.dart
export 'message_audio_builder_stub.dart'
    if (dart.library.io) 'message_audio_builder_mobile.dart';
