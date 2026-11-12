/// 消息类型别称 → 现役类型 的单一映射源（W5-G3-4 别名去重）。
///
/// 历史上同一组别称有三处副本，口径靠人肉同步：
/// - 导出准入 `chat_export_admission.dart` 的 `_kTypeAliases`（已改引用本表）；
/// - `MessageTypeNormalizer._legacyAliases` + `_canonical`（已改引用本表）；
/// - `message_preview_text.dart` 的 webrtc 下划线双 case（已改引用本表）。
/// 新增别称只改这里，三处消费方自动一致。
///
/// 纯 Dart、零副作用：不 iPrint、不 import Flutter——application/export
/// 纯净层与 UI 层均可安全引用（与 `MessageTypeNormalizer.normalize` 的
/// 日志副作用无关）。
///
/// ⚠️ 各消费方的**归一范围**保持其历史口径（特征化测试锁定，见
/// `test/unit_test/modules/messaging/export/message_type_alias_characterization_test.dart`）：
/// - 导出准入用全量表（[MessageTypeAlias.all] + trim）；
/// - Normalizer 只用频道历史表（aliasOf）+ 协议表（_canonical），
///   webrtc 下划线脏值在其口径内仍是无效类型；
/// - `messagePreviewText` 只归一 webrtc 下划线表（不 trim、不归一
///   channel_message——列表预览该分支维持 default 兜底现状）。
library;

import 'package:imboy/service/message_type_constants.dart';

/// 消息类型别称表（纯数据，不可实例化）。
abstract final class MessageTypeAlias {
  MessageTypeAlias._();

  /// 频道分享历史别称：`channel_message`（2026-10-30 前落库的私有
  /// msg_type，全站无 builder）→ 现役 `channel_card`。
  ///
  /// 刻意不进 `MessageType.allTypes`：它不合法、不可发送、可随时移除。
  static const Map<String, String> channelShareLegacy = <String, String>{
    MessageType.legacyChannelMessage: MessageType.channelCard,
  };

  /// 协议别称：`audio` 是 protobuf 通道（ContentType.AUDIO）与收藏恢复
  /// 链路（kind=3）产出的协议别称，全站发送口径与渲染注册都是 `voice`。
  static const Map<String, String> protocolVoice = <String, String>{
    MessageType.audio: MessageType.voice,
  };

  /// 历史脏数据可能以下划线命名持久化，常量是驼峰。
  static const Map<String, String> underscoreWebrtc = <String, String>{
    'webrtc_audio': MessageType.webrtcAudio,
    'webrtc_video': MessageType.webrtcVideo,
  };

  /// 全量别称表（= 上面三张表的并集；导出准入口径）。
  static const Map<String, String> all = <String, String>{
    ...channelShareLegacy,
    ...protocolVoice,
    ...underscoreWebrtc,
  };

  /// trim + 全量别称归一：非别称原样返回（不校验有效性、无副作用）。
  static String canonicalOf(String raw) {
    final trimmed = raw.trim();
    return all[trimmed] ?? trimmed;
  }
}
