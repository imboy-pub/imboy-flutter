/// 合并转发聊天记录详情页（W3-I / chat_history_bundle_v1 接收侧）。
///
/// 列表展示 bundle entries：sender_name + 时间 + 类型安全渲染。
/// **数据全部来自消息 payload 的转发时快照**（PLAN_SNAPSHOT §4.5：
/// 详情页不回查原会话）——本页不做任何网络/仓储查询。
///
/// 类型安全口径：
/// - text/expression/quote → 快照文本；
/// - image/imageMulti → 缩略图**必须经 [AssetsService.viewUrl] 授权**
///   （禁止直连原始 URL），无 uri（未回写引用）时渲染占位图；
/// - voice/video/file/location → 图标 + 显示字段（name/filename/size/
///   duration_ms，均为 sanitizer 允许的展示字段占位）；
/// - 其余/未知 entry 类型 → fallback 描述（不崩溃、不猜测）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart'
    show historyBundleEntries, historyBundleEntryIcon;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/assets.dart' show AssetsService;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class HistoryBundleDetailPage extends StatelessWidget {
  const HistoryBundleDetailPage({super.key, required this.bundle});

  /// bundle 快照（含 bundle_version/title/exported_at/entries；
  /// 来自消息 metadata，mapper 已原样透传）。
  final Map<String, dynamic> bundle;

  @override
  Widget build(BuildContext context) {
    final entries = historyBundleEntries(bundle);
    final String title = (bundle['title']?.toString() ?? '').trim().isNotEmpty
        ? bundle['title'].toString()
        : t.chat.bundleTitle;
    final String exportedAt = DateTimeHelper.millisFmtOrEmpty(
      bundle['exported_at'],
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(t.chat.bundleTitle)),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
          itemCount: entries.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _BundleHeader(
                title: title,
                exportedAt: exportedAt,
                count: entries.length,
              );
            }
            final entry = entries[index - 1];
            return _BundleEntryRow(
              key: Key('history_bundle_entry_${index - 1}'),
              entry: entry,
            );
          },
        ),
      ),
    );
  }
}

class _BundleHeader extends StatelessWidget {
  const _BundleHeader({
    required this.title,
    required this.exportedAt,
    required this.count,
  });

  final String title;
  final String exportedAt;
  final int count;

  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textStyle(
              FontSizeType.large,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            exportedAt.isEmpty
                ? t.chat.bundlePreview(count: count)
                : '${t.chat.bundlePreview(count: count)} · $exportedAt',
            style: context.textStyle(FontSizeType.small, color: sub),
          ),
          const SizedBox(height: AppSpacing.tiny),
          Divider(height: 1, color: sub.withValues(alpha: 0.2)),
        ],
      ),
    );
  }
}

class _BundleEntryRow extends StatelessWidget {
  const _BundleEntryRow({super.key, required this.entry});

  final Map<String, dynamic> entry;

  static String _str(Map<String, dynamic> payload, String key) =>
      (payload[key]?.toString() ?? '').trim();

  Map<String, dynamic> get _payload => entry['payload'] is Map
      ? Map<String, dynamic>.from(entry['payload'] as Map)
      : const <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final msgType = entry['msg_type']?.toString() ?? '';
    final payload = _payload;
    final sender = (entry['sender_name']?.toString() ?? '').trim();
    final sentAt = DateTimeHelper.millisFmtOrEmpty(entry['sent_at']);
    final sub = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                historyBundleEntryIcon(msgType),
                size: AppSpacing.regular,
                color: AppColors.slateText,
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  sender.isEmpty ? t.chat.bundleTitle : sender,
                  style: context.textStyle(
                    FontSizeType.small,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sentAt.isNotEmpty)
                Text(
                  sentAt,
                  style: context.textStyle(FontSizeType.tiny, color: sub),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          // 正文区：类型安全渲染，未知类型 fallback
          _entryContent(context, msgType, payload, sub),
        ],
      ),
    );
  }

  Widget _entryContent(
    BuildContext context,
    String msgType,
    Map<String, dynamic> payload,
    Color sub,
  ) {
    switch (msgType) {
      case MessageType.text:
      case MessageType.textStream:
        return _textBody(
          context,
          _str(payload, 'text').isNotEmpty
              ? _str(payload, 'text')
              : _str(payload, 'content'),
          sub,
        );

      case MessageType.expression:
        return _textBody(context, _str(payload, 'text'), sub);

      case MessageType.quote:
        // sanitizer 已扁平化为 {text, quote_text}
        final text = _str(payload, 'text');
        final quoted = _str(payload, 'quote_text');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (text.isNotEmpty) _textBody(context, text, null),
            if (quoted.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.tiny),
                child: _textBody(context, quoted, sub.withValues(alpha: 0.7)),
              ),
          ],
        );

      case MessageType.image:
        return _ImageSnapshotThumb(uri: _str(payload, 'uri'), count: 0);

      case MessageType.imageMulti:
        return _ImageSnapshotThumb(
          uri: _str(payload, 'uri'),
          count: payload['total'] is int ? payload['total'] as int : 0,
        );

      case MessageType.voice:
        final durationMs = payload['duration_ms'] is int
            ? payload['duration_ms'] as int
            : 0;
        final seconds = (durationMs / 1000).round();
        return _metaBody(
          context,
          historyBundleEntryIcon(MessageType.voice),
          seconds > 0 ? '$seconds″' : t.chat.voiceMessage,
          sub,
        );

      case MessageType.video:
        return _metaBody(
          context,
          historyBundleEntryIcon(MessageType.video),
          _str(payload, 'name').isNotEmpty
              ? _str(payload, 'name')
              : t.chat.videoMessage,
          sub,
        );

      case MessageType.file:
        final size = payload['size'] is int ? payload['size'] as int : null;
        final name = _str(payload, 'filename').isNotEmpty
            ? _str(payload, 'filename')
            : _str(payload, 'name');
        return _metaBody(
          context,
          historyBundleEntryIcon(MessageType.file),
          name.isNotEmpty
              ? (size != null ? '$name（${_formatBytes(size)}）' : name)
              : t.chat.file,
          sub,
        );

      case MessageType.location:
        final label = _str(payload, 'title').isNotEmpty
            ? _str(payload, 'title')
            : _str(payload, 'address');
        return _metaBody(
          context,
          historyBundleEntryIcon(MessageType.location),
          label.isNotEmpty ? label : t.common.locationMessage,
          sub,
        );

      default:
        // unknown/unsupported entry：安全描述，不猜测、不崩溃
        return _metaBody(
          context,
          historyBundleEntryIcon(msgType),
          t.chat.unsupportedMessageType,
          sub,
        );
    }
  }

  Widget _textBody(BuildContext context, String text, Color? color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: context
          .textStyle(
            FontSizeType.body,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          )
          .copyWith(height: 1.4),
    );
  }

  Widget _metaBody(
    BuildContext context,
    IconData icon,
    String label,
    Color sub,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSpacing.regular, color: sub),
        const SizedBox(width: AppSpacing.small),
        Flexible(
          child: Text(
            label,
            style: context.textStyle(FontSizeType.small, color: sub),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

/// 图片条目快照缩略图。
///
/// uri 是转发器按**新 message id/目标会话**重新封装后的引用；渲染前必须经
/// [AssetsService.viewUrl] 授权（禁止直连原始 URL）。无 uri（构建期仅保留
/// 显示字段占位、引用未回写）或加载失败时渲染占位图。
class _ImageSnapshotThumb extends StatelessWidget {
  const _ImageSnapshotThumb({required this.uri, required this.count});

  final String uri;
  final int count;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // 占位/失败底色随主题走（与 message_image_builder 同款 token）
    final placeholderFg = isDark
        ? AppColors.mediaScrimWhite.withValues(alpha: 0.5)
        : AppColors.mediaScrimBlack.withValues(alpha: 0.4);
    final placeholder = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.placeholderSurfaceDark
            : AppColors.placeholderSurfaceLight,
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(CupertinoIcons.photo, size: 32, color: placeholderFg),
          if (count > 1)
            Positioned(
              right: AppSpacing.tiny,
              bottom: AppSpacing.tiny,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.tiny,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slateText.withValues(alpha: 0.8),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Text(
                  '$count',
                  style: context.textStyle(
                    FontSizeType.tiny,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (uri.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: AppRadius.borderRadiusSmall,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Image.network(
          // 授权访问：附件 URL 必须经 AssetsService.viewUrl（AGENTS 编码规范）
          AssetsService.viewUrl(uri).toString(),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}
