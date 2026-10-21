import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_collaboration_summary.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 会话列表 / 通知等「聊天页之外」的消息预览文案 —— 单一事实源。
///
/// 聊天页（CustomMessageBuilder 插件链）能渲染的消息类型，这里都要给出
/// 对应的可读摘要；新增消息类型时先补本函数，各列表/通知自动生效。
/// 历史：WorkspaceConversationModel 只白名单了 5 种类型，群作业 / 群投票 /
/// 群日程 / 语音 / 红包等一律显示「[不支持的消息]」，与聊天页的实际渲染能力
/// 脱节（EO-20261009）。此前 ConversationModel.content、
/// offline_message_writer._derivePreview、message._messageTypeLabel 各写一份
/// 白名单，漏掉的类型就在个别入口显示「[未知消息]」——本函数收口避免再分叉。
///
/// [fallbackSubtitle] 是各列表自有的摘要兜底（如 conversation.subtitle），
/// 仅当 payload 提取不到可读文本时才采用，且「[...]」形式的旧类型标签
/// （'[位置]'、'[文件]' 等）会被过滤，避免「[群作业][未知消息]」式叠加。
String messagePreviewText(
  String msgType,
  Map<dynamic, dynamic>? payload, {
  String fallback = '[消息]',
  String fallbackSubtitle = '',
}) {
  final body = payload ?? const <String, dynamic>{};

  // 群协作卡（群作业/群投票/群日程）：卡片标题优先，模块内自带 generic 过滤
  final collaboration = groupCollaborationSummary(
    msgType,
    Map<String, dynamic>.from(body),
    includeLabel: true,
    fallbackTitle: fallbackSubtitle,
  );
  if (collaboration != null) return collaboration;

  final subtitle = _readableFallbackSubtitle(fallbackSubtitle);

  switch (msgType) {
    case MessageType.text:
    case MessageType.textStream:
      // textStream 与 text 同构（payload['text'] 承载当前分片正文）
      final text = body['text']?.toString() ?? '';
      if (text.trim().isNotEmpty) return text.trim();
      // 历史文本消息可能把正文放在 content 字段（原 previewText 同款兜底）
      final content = body['content']?.toString() ?? '';
      if (content.trim().isNotEmpty) return content.trim();
      return subtitle.isNotEmpty ? subtitle : fallback;

    case MessageType.quote:
      // 引用消息优先显示回复正文，其次被引用文本
      final text = body['text']?.toString() ?? '';
      if (text.trim().isNotEmpty) return text.trim();
      final quoted = body['quote_text']?.toString() ?? '';
      return _firstReadable(quoted, subtitle, fallback);

    case MessageType.image:
    case MessageType.imageMulti:
      return t.chat.imageMessage;

    case MessageType.video:
      return t.chat.videoMessage;

    case MessageType.voice:
    case MessageType.audio:
      // 'audio' 是 protobuf/收藏链路的协议别称，渲染真值为 voice
      return '[${t.chat.voiceMessage}]';

    case MessageType.file:
      final filename = body['filename']?.toString() ?? '';
      if (filename.trim().isNotEmpty) return filename.trim();
      final name = body['name']?.toString() ?? '';
      if (name.trim().isNotEmpty) return name.trim();
      return '[${t.chat.file}]';

    case MessageType.location:
      final title = (body['title']?.toString() ?? '').trim();
      // payload 无标题时退化为列表自有摘要（历史数据地址在 subtitle）
      final place = title.isNotEmpty ? title : subtitle;
      final label = '[${t.common.locationMessage}]';
      return place.isNotEmpty ? '$label$place' : label;

    case MessageType.expression:
      // 表情自带可读文本（如「[微笑]」）；历史数据 payload 可能没存 text，
      // 退化为列表自有摘要，最后才是类型标签
      final text = body['text']?.toString() ?? '';
      if (text.trim().isNotEmpty) return text.trim();
      return subtitle.isNotEmpty ? subtitle : '[${t.common.expression}]';

    case MessageType.webrtcAudio:
      return '[${t.common.voiceCall}]';

    case MessageType.webrtcVideo:
      return '[${t.common.videoCall}]';

    // ⚠️ 历史脏数据可能用下划线命名持久化，常量是驼峰——双 case 都接住，
    // 避免新旧数据都 fallback 成「[消息]」（原 message._messageTypeLabel 同款）
    case 'webrtc_audio':
      return '[${t.common.voiceCall}]';

    case 'webrtc_video':
      return '[${t.common.videoCall}]';

    case 'revoked':
      return '[${t.common.messageRevoked}]';

    case MessageType.redPacket:
      final greeting = body['greeting']?.toString() ?? '';
      final label = '[${t.common.redPacket}]';
      return greeting.trim().isNotEmpty ? '$label${greeting.trim()}' : label;

    case MessageType.transfer:
      final remark = body['remark']?.toString() ?? '';
      final label = '[${t.common.transfer}]';
      return remark.trim().isNotEmpty ? '$label${remark.trim()}' : label;

    case MessageType.visitCard:
      return '[${t.common.personalCard}]';

    case MessageType.talkRecordCard:
      return '[${t.talkRecord.entryTitle}]';
    case MessageType.channelCard:
      return '[${t.chat.card}]';

    case MessageType.custom:
    case MessageType.unsupported:
    default:
      // 未识别类型与聊天页的兜底口径对齐：先尝试常见可读字段，
      // 再退回列表自有摘要，最后给通用「[消息]」——
      // 不再出现「[不支持的消息]」这类实现细节措辞。
      for (final key in const ['title', 'text', 'name', 'content']) {
        final v = body[key]?.toString() ?? '';
        if (v.trim().isNotEmpty) return v.trim();
      }
      return subtitle.isNotEmpty ? subtitle : fallback;
  }
}

String _firstReadable(String a, String b, String fallback) {
  if (a.trim().isNotEmpty) return a.trim();
  if (b.isNotEmpty) return b;
  return fallback;
}

/// 列表自有摘要兜底：过滤旧落库的「[...]」形式类型标签，
/// 它们是历史版本的类型占位（如 '[位置]'、'[未知消息]'），拼回去会叠加显示。
String _readableFallbackSubtitle(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  if (s.startsWith('[') && s.endsWith(']')) return '';
  return s;
}
