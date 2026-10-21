part of 'message_type_constants.dart';

// ============================================
// 消息类型枚举 (类型安全)
// ============================================

/// 用户消息类型枚举
///
/// 提供 类型安全的消息类型定义
/// 统一映射 `MessageType` 中定义的消息类型常量
///
/// 使用示例：
/// ```dart
/// MsgTypeEnum type = MsgTypeEnum.image;
/// String typeStr = type.value;  // 'image'
/// ```
enum MsgTypeEnum {
  /// 文本消息
  text,

  /// 文本流消息（AI对话等流式输出）
  textStream,

  /// 图片消息
  image,

  /// 多图消息（一次发送多张图片）
  imageMulti,

  /// 文件消息
  file,

  /// 位置消息
  location,

  /// 表情消息
  expression,

  /// 语音消息（使用 voice 命名，符合 WebSocket API v2.0 规范）
  voice,

  /// 视频消息
  video,

  /// 不支持的消息类型
  unsupported,

  /// 自定义消息
  custom,

  /// WebRTC 音频通话
  webrtcAudio,

  /// WebRTC 视频通话
  webrtcVideo,

  /// 引用消息
  quote,

  /// 红包消息
  redPacket,

  /// 转账消息
  transfer,

  /// 频道卡片消息
  channelCard,
  talkRecordCard,
}

/// MsgTypeEnum 扩展方法
extension MsgTypeEnumExtension on MsgTypeEnum {
  /// 获取枚举对应的字符串值
  String get value {
    switch (this) {
      case MsgTypeEnum.text:
        return MessageType.text;
      case MsgTypeEnum.textStream:
        return MessageType.textStream;
      case MsgTypeEnum.image:
        return MessageType.image;
      case MsgTypeEnum.imageMulti:
        return MessageType.imageMulti;
      case MsgTypeEnum.file:
        return MessageType.file;
      case MsgTypeEnum.location:
        return MessageType.location;
      case MsgTypeEnum.expression:
        return MessageType.expression;
      case MsgTypeEnum.voice:
        return MessageType.voice;
      case MsgTypeEnum.video:
        return MessageType.video;
      case MsgTypeEnum.unsupported:
        return MessageType.unsupported;
      case MsgTypeEnum.custom:
        return MessageType.custom;
      case MsgTypeEnum.webrtcAudio:
        return MessageType.webrtcAudio;
      case MsgTypeEnum.webrtcVideo:
        return MessageType.webrtcVideo;
      case MsgTypeEnum.quote:
        return MessageType.quote;
      case MsgTypeEnum.redPacket:
        return MessageType.redPacket;
      case MsgTypeEnum.transfer:
        return MessageType.transfer;
      case MsgTypeEnum.channelCard:
        return MessageType.channelCard;
      case MsgTypeEnum.talkRecordCard:
        return MessageType.talkRecordCard;
    }
  }

  /// 从字符串值获取枚举
  static MsgTypeEnum? fromValue(String value) {
    switch (value) {
      case MessageType.text:
        return MsgTypeEnum.text;
      case MessageType.textStream:
        return MsgTypeEnum.textStream;
      case MessageType.image:
        return MsgTypeEnum.image;
      case MessageType.imageMulti:
        return MsgTypeEnum.imageMulti;
      case MessageType.file:
        return MsgTypeEnum.file;
      case MessageType.location:
        return MsgTypeEnum.location;
      case MessageType.expression:
        return MsgTypeEnum.expression;
      case MessageType.voice:
        return MsgTypeEnum.voice;
      case MessageType.video:
        return MsgTypeEnum.video;
      case MessageType.unsupported:
        return MsgTypeEnum.unsupported;
      case MessageType.custom:
        return MsgTypeEnum.custom;
      case MessageType.webrtcAudio:
        return MsgTypeEnum.webrtcAudio;
      case MessageType.webrtcVideo:
        return MsgTypeEnum.webrtcVideo;
      case MessageType.quote:
        return MsgTypeEnum.quote;
      case MessageType.redPacket:
        return MsgTypeEnum.redPacket;
      case MessageType.transfer:
        return MsgTypeEnum.transfer;
      case MessageType.channelCard:
        return MsgTypeEnum.channelCard;
      case MessageType.talkRecordCard:
        return MsgTypeEnum.talkRecordCard;
      default:
        return null;
    }
  }
}
