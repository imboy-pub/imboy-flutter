import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_collaboration_summary.dart';
import 'package:imboy/service/message_type_alias.dart';
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

  // 历史脏数据可能用下划线命名持久化（webrtc_audio/webrtc_video），
  // 常量是驼峰——经共享别称表（MessageTypeAlias.underscoreWebrtc，
  // W5-G3-4 收口，替代原双 case）归一后匹配。
  // ⚠️ 仅归一这一类：audio 由 voice 分支显式双 case 接住，
  // channel_message 等其余别称的列表口径维持各自分支现状
  // （特征化测试锁定，不 trim）。
  final type = MessageTypeAlias.underscoreWebrtc[msgType] ?? msgType;
  switch (type) {
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

    case 'revoked':
      return '[${t.common.messageRevoked}]';

    case MessageType.chatHistoryBundle:
      // 合并转发聊天记录：摘要给出条数（entries 缺失/畸形的极端行按 0 条
      // 展示，保持类型标签可辨识）；正文细节只在详情页展示。
      final entries = body['entries'];
      return t.chat.bundlePreview(count: entries is List ? entries.length : 0);

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
      // 频道名片/频道内容分享：会话列表优先显示频道名或内容摘要，
      // 只有两者都缺时才退化成「名片」标签（否则分享一篇文章在列表里
      // 只看到「[名片]」，看不出分享的是什么）。
      final shown =
          (body['content']?.toString() ??
                  body['channel_name']?.toString() ??
                  body['title']?.toString() ??
                  '')
              .trim();
      return shown.isNotEmpty ? shown : '[${t.chat.card}]';

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
