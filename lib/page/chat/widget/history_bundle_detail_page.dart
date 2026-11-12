/// 合并转发聊天记录详情页（W3-I / chat_history_bundle_v1 接收侧）。
///
/// 列表展示 bundle entries：sender_name + 时间 + 类型安全渲染。
/// **数据全部来自消息 payload 的转发时快照**（PLAN_SNAPSHOT §4.5：
/// 详情页不回查原会话）——本页不做任何网络/仓储查询。
///
/// 类型安全口径：
/// - text/expression/quote → 快照文本；
/// - image/imageMulti → 缩略图必须经授权图片管线（[IMBoyCachedImageProvider]，
///   object_key 原样透传由下载边界异步换取短时 URL；禁止直连原始 URL），
///   无 uri（未回写引用）时渲染占位图；
/// - voice/video/file/location → 图标 + 显示字段（name/filename/size/
///   duration_ms，均为 sanitizer 允许的展示字段占位）；
/// - 其余/未知 entry 类型 → fallback 描述（不崩溃、不猜测）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart'
    show historyBundleEntries, historyBundleEntryIcon;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/assets.dart' show AssetsService;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 快照缩略图正方形边长（逻辑像素；解码宽按 容器宽 × DPR 换算）。
const double _kThumbSize = 96;

/// 占位/失败占位图内的 photo 图标尺寸。
const double _kThumbPlaceholderIconSize = 32;

class HistoryBundleDetailPage extends StatelessWidget {
  const HistoryBundleDetailPage({super.key, required this.bundle});

  /// bundle 快照（含 bundle_version/title/exported_at/entries；
  /// 来自消息 metadata，mapper 已原样透传）。
  final Map<String, dynamic> bundle;

  @override
  Widget build(BuildContext context) {
    final entries = historyBundleEntries(bundle);
    final String rawTitle = bundle['title']?.toString() ?? '';
    final String title = rawTitle.trim().isNotEmpty
        ? rawTitle
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
              entryIndex: index - 1,
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
  const _BundleEntryRow({
    super.key,
    required this.entry,
    required this.entryIndex,
  });

  final Map<String, dynamic> entry;

  /// entry 在 bundle 中的序号（缩略图 ValueKey 用，见 [_ImageSnapshotThumb]）。
  final int entryIndex;

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
                  sender.isEmpty ? t.chat.unknownSender : sender,
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

  /// 正文渲染：单一分支消费 [_entryBodyOf] 的纯函数产出。
  Widget _entryContent(
    BuildContext context,
    String msgType,
    Map<String, dynamic> payload,
    Color sub,
  ) {
    return switch (_entryBodyOf(msgType, payload)) {
      _EntryTextBody(:final text) => _textBody(context, text, sub),
      _EntryQuoteBody(:final text, :final quoted) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty) _textBody(context, text, null),
          if (quoted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.tiny),
              child: _textBody(context, quoted, sub.withValues(alpha: 0.7)),
            ),
        ],
      ),
      _EntryImageBody(:final uri, :final count) => _ImageSnapshotThumb(
        uri: uri,
        count: count,
        index: entryIndex,
      ),
      _EntryMetaBody(:final label) => _metaBody(
        context,
        historyBundleEntryIcon(msgType),
        label,
        sub,
      ),
    };
  }

  /// entry 正文纯函数：把 (msgType, payload) 归一为 [_EntryBody] 正文数据
  /// （每个显示字段只求值一次），渲染交给 [_entryContent] 的单一分支。
  static _EntryBody _entryBodyOf(String msgType, Map<String, dynamic> payload) {
    switch (msgType) {
      case MessageType.text:
      case MessageType.textStream:
        final text = _str(payload, 'text');
        return _EntryTextBody(
          text.isNotEmpty ? text : _str(payload, 'content'),
        );

      case MessageType.expression:
        return _EntryTextBody(_str(payload, 'text'));

      case MessageType.quote:
        // sanitizer 已扁平化为 {text, quote_text}
        return _EntryQuoteBody(
          _str(payload, 'text'),
          _str(payload, 'quote_text'),
        );

      case MessageType.image:
        return _EntryImageBody(_str(payload, 'uri'), 0);

      case MessageType.imageMulti:
        return _EntryImageBody(
          _str(payload, 'uri'),
          payload['total'] is int ? payload['total'] as int : 0,
        );

      case MessageType.voice:
        final durationMs = payload['duration_ms'] is int
            ? payload['duration_ms'] as int
            : 0;
        final seconds = (durationMs / 1000).round();
        return _EntryMetaBody(
          seconds > 0
              ? t.chat.voiceDurationSeconds(seconds: seconds)
              : t.chat.voiceMessage,
        );

      case MessageType.video:
        final name = _str(payload, 'name');
        return _EntryMetaBody(name.isNotEmpty ? name : t.chat.videoMessage);

      case MessageType.file:
        final filename = _str(payload, 'filename');
        final name = filename.isNotEmpty ? filename : _str(payload, 'name');
        final size = payload['size'] is int ? payload['size'] as int : null;
        return _EntryMetaBody(
          name.isNotEmpty
              ? (size != null
                    ? t.chat.fileWithNameSize(
                        name: name,
                        size: _formatBytes(size),
                      )
                    : name)
              : t.chat.file,
        );

      case MessageType.location:
        final title = _str(payload, 'title');
        final label = title.isNotEmpty ? title : _str(payload, 'address');
        return _EntryMetaBody(
          label.isNotEmpty ? label : t.common.locationMessage,
        );

      default:
        // unknown/unsupported entry：安全描述，不猜测、不崩溃
        return _EntryMetaBody(t.chat.unsupportedMessageType);
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

/// entry 正文数据模型（[_BundleEntryRow._entryBodyOf] 纯函数产出，
/// 正文渲染按类型单一分支消费）。
sealed class _EntryBody {
  const _EntryBody();
}

/// 纯文本正文（text/textStream/expression）。
final class _EntryTextBody extends _EntryBody {
  const _EntryTextBody(this.text);
  final String text;
}

/// 引用正文（正文 + 被引用文本）。
final class _EntryQuoteBody extends _EntryBody {
  const _EntryQuoteBody(this.text, this.quoted);
  final String text;
  final String quoted;
}

/// 图片快照（缩略图 uri + 图片数量角标）。
final class _EntryImageBody extends _EntryBody {
  const _EntryImageBody(this.uri, this.count);
  final String uri;
  final int count;
}

/// 图标 + 单行描述（voice/video/file/location/未知类型 fallback）。
final class _EntryMetaBody extends _EntryBody {
  const _EntryMetaBody(this.label);
  final String label;
}

/// 图片条目快照缩略图。
///
/// uri 是转发器按**新 message id/目标会话**重新封装后的引用（Garage
/// object_key 或完整 URL）；渲染必须走授权图片管线
/// [IMBoyCachedImageProvider]（与 `cachedImageProvider` 同口径：object_key
/// 原样透传、由下载边界异步换取短时 presigned URL）。**禁止**
/// `Image.network(AssetsService.viewUrl(uri))`：viewUrl 对 object_key 只
/// 返回无 scheme 的相对 `Uri(path:)`，喂给 NetworkImage 必然抛错、被
/// errorBuilder 吞掉 → 缩略图永远占位。无 uri（构建期仅保留显示字段
/// 占位、引用未回写）或加载失败时渲染占位图。
class _ImageSnapshotThumb extends StatelessWidget {
  const _ImageSnapshotThumb({
    required this.uri,
    required this.count,
    required this.index,
  });

  final String uri;
  final int count;

  /// entry 序号：真实图片 widget 的 ValueKey（`bundle_detail_thumb_<index>`），
  /// 设备旅程按此 key 定位断言（key 名冻结，逐字一致）。
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // 占位/失败底色随主题走（与 message_image_builder 同款 token）
    final placeholderFg = isDark
        ? AppColors.mediaScrimWhite.withValues(alpha: 0.5)
        : AppColors.mediaScrimBlack.withValues(alpha: 0.4);
    final placeholder = Container(
      width: _kThumbSize,
      height: _kThumbSize,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.placeholderSurfaceDark
            : AppColors.placeholderSurfaceLight,
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            CupertinoIcons.photo,
            size: _kThumbPlaceholderIconSize,
            color: placeholderFg,
          ),
          if (count > 1)
            Positioned(
              right: AppSpacing.tiny,
              bottom: AppSpacing.tiny,
              child: Container(
                // AppSpacing 为 4px 基数体系、无 2px token；数量角标上下
                // 2px 是刻意的小内边距，保留字面量。
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

    // 授权访问：附件渲染必须经 IMBoyCachedImageProvider（AGENTS 编码规范；
    // object_key 原样透传，完整 URL 同步 viewUrl 授权——参考 func.dart 的
    // cachedImageProvider；Garage 不支持 URL 缩放参数，解码缩放由
    // cacheWidth 在客户端完成）。
    final headers = <String, String>{'User-Agent': 'imboy/1.0.0'};
    final ImageProvider<Object> provider = AssetsService.isObjectKey(uri)
        ? IMBoyCachedImageProvider(uri, headers)
        : IMBoyCachedImageProvider(
            AssetsService.viewUrl(uri).toString(),
            headers,
          );

    return ClipRRect(
      borderRadius: AppRadius.borderRadiusSmall,
      child: SizedBox(
        width: _kThumbSize,
        height: _kThumbSize,
        child: Image(
          key: ValueKey('bundle_detail_thumb_$index'),
          // 解码宽 = 容器宽 × DPR（本 SDK 基础 Image 构造无 cacheWidth
          // 参数，经 ResizeImage 包裹等价实现，避免全尺寸位图进内存）
          image: ResizeImage.resizeIfNeeded(
            (_kThumbSize * MediaQuery.devicePixelRatioOf(context)).round(),
            null,
            provider,
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}
