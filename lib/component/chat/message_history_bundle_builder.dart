/// `chat_history_bundle` 消息气泡 + 条目小图标（W3-I / chat_history_bundle_v1）。
///
/// 渲染**接收侧**合并转发聊天记录：气泡展示 title（缺省回退
/// `chat.bundleTitle`）+ 条数 + entry 类型小图标；点击经 GoRoute
/// `/chat/history_bundle`（extra 携带 bundle 快照 Map）打开详情页。
///
/// 数据全部来自消息 payload 的**转发时快照**（mapper 已把 bundle payload
/// 原样放进 metadata），详情页不回查原会话（PLAN_SNAPSHOT §4.5）。
/// 旧客户端（registry 未注册本类型）由 fallback 渲染成
/// 「不支持的消息类型」（COMP-01 fixture 钉住该行为）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 详情页路由（extra 传 bundle 快照 Map；注册见 app_router.dart）。
const String kHistoryBundleDetailRoute = '/chat/history_bundle';

/// bubble/详情页共用的 entry 类型小图标。
///
/// 归一口径与 `MessageTypeNormalizer` 一致（audio→voice）；未知类型给
/// question 图标（详情页对未知 entry 另有 fallback 描述文案）。
IconData historyBundleEntryIcon(String msgType) {
  switch (msgType) {
    case MessageType.text:
    case MessageType.textStream:
      return CupertinoIcons.text_alignleft;
    case MessageType.image:
    case MessageType.imageMulti:
      return CupertinoIcons.photo;
    case MessageType.voice:
    case MessageType.audio:
      return CupertinoIcons.waveform;
    case MessageType.video:
      return CupertinoIcons.videocam;
    case MessageType.file:
      return CupertinoIcons.doc;
    case MessageType.location:
      return CupertinoIcons.location;
    case MessageType.expression:
      return CupertinoIcons.smiley;
    case MessageType.quote:
      return CupertinoIcons.text_bubble;
    default:
      return CupertinoIcons.question;
  }
}

/// 从 bundle 快照 Map 里解析 entries（容忍畸形行，恒返回 List）。
List<Map<String, dynamic>> historyBundleEntries(Map<String, dynamic>? data) {
  final raw = data?['entries'];
  if (raw is! List) return const <Map<String, dynamic>>[];
  return [
    for (final e in raw)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

/// 合并转发聊天记录气泡。
class HistoryBundleMessageBuilder extends StatelessWidget {
  const HistoryBundleMessageBuilder({
    super.key,
    required this.user,
    required this.message,
  });

  final User user;
  final CustomMessage message;

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata ?? const <String, dynamic>{};
    final entries = historyBundleEntries(meta);
    final bool sentByMe = user.id == message.authorId;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = sentByMe
        ? AppColors.sentMessageText
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final Color subTextColor = sentByMe
        ? AppColors.overlayWhite70
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    // bundle title 缺省回退通用标签（发送方可选填，如来源会话名快照）
    final String title = (meta['title']?.toString() ?? '').trim().isNotEmpty
        ? (meta['title']!.toString())
        : t.chat.bundleTitle;
    final List<IconData> icons = _collectTypeIcons(entries);

    return GestureDetector(
      key: Key('history_bundle_bubble_${message.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(
        kHistoryBundleDetailRoute,
        extra: Map<String, dynamic>.from(meta),
      ),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: _bubbleDecoration(
          sentByMe,
          isDark,
          Theme.of(context).brightness,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, title, textColor),
            const SizedBox(height: AppSpacing.tiny),
            _buildPreview(context, entries.length, subTextColor),
            ..._buildTypeIcons(icons, subTextColor),
          ],
        ),
      ),
    );
  }

  /// entry 类型小图标：按首次出现顺序去重，最多展示 6 个。
  List<IconData> _collectTypeIcons(List<Map<String, dynamic>> entries) {
    final List<IconData> icons = <IconData>[];
    for (final e in entries) {
      final icon = historyBundleEntryIcon(e['msg_type']?.toString() ?? '');
      if (!icons.contains(icon)) icons.add(icon);
      if (icons.length >= 6) break;
    }
    return icons;
  }

  /// 气泡容器装饰：气泡底色 + 圆角 + 接收侧浅色模式细边框。
  BoxDecoration _bubbleDecoration(
    bool sentByMe,
    bool isDark,
    Brightness brightness,
  ) => BoxDecoration(
    color: AppColors.getChatBubbleBackground(sentByMe, false, brightness),
    borderRadius: MessageSpacing.getBubbleBorderRadius(sentByMe),
    border: !sentByMe && !isDark
        ? Border.all(color: AppColors.iosGray5, width: 0.5)
        : null,
  );

  /// 头部：bundle 图标 + title（最多两行省略）。
  Widget _buildHeader(BuildContext context, String title, Color textColor) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.square_stack_3d_up,
            size: AppSpacing.xLarge,
            color: textColor,
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              title,
              style: context.textStyle(
                FontSizeType.medium,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  /// 条数预览文案（单行省略）。
  Widget _buildPreview(BuildContext context, int count, Color subTextColor) =>
      Text(
        t.chat.bundlePreview(count: count),
        style: context.textStyle(FontSizeType.small, color: subTextColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  /// entry 类型小图标流（空列表时不占位）。
  List<Widget> _buildTypeIcons(List<IconData> icons, Color subTextColor) {
    if (icons.isEmpty) return const <Widget>[];
    return [
      const SizedBox(height: AppSpacing.small),
      Wrap(
        spacing: AppSpacing.small,
        runSpacing: AppSpacing.tiny,
        children: [
          for (final icon in icons)
            Icon(icon, size: AppSpacing.regular, color: subTextColor),
        ],
      ),
    ];
  }
}

/// builtin 插件：`chat_history_bundle` → [HistoryBundleMessageBuilder]。
///
/// surface=standalone：卡片自绘气泡容器（与链接卡片同范式），
/// 不再套默认气泡。
class ChatHistoryBundleMessageTypePlugin implements MessageTypePlugin {
  const ChatHistoryBundleMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.chatHistoryBundle}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.chatHistoryBundle;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return HistoryBundleMessageBuilder(user: context.user, message: message);
  }
}
