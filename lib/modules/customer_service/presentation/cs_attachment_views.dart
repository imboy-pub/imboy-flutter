/// 坐席会话附件渲染（CS-APP-01，CSX-01 冻结投影的最小渲染复用）。
///
/// 输入是历史消息 `assets:[{id,mime,size_bytes,file_name,status}]` 投影：
/// - 图片（`image/*`）：经授权 content 代理取字节后 `Image.memory` 缩略
///   渲染（**禁止** `Image.network`/`CachedNetworkImage` 裸 URL——客户端
///   不持有任何可裸访问的对象 URL，EB-D06）；
/// - 普通文件：最小文件行（图标 + 文件名 + 人类可读大小），点击预览。
///
/// 字节获取由调用方（会话页经 CsSessionFlow.fetchAssetBytes，含只读态
/// 门控与降级分类）注入 [bytesLoader]；组件自身零网络。
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 人类可读字节数（服务端投影的 size_bytes 权威值）。
String csFormatAssetSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// 单条附件的气泡内渲染：图片缩略 / 文件行 分型。
class CsAssetAttachmentView extends StatelessWidget {
  final CsMessageAsset asset;

  /// 授权字节获取（图片渲染与文本预览共用；null = 已降级/不可用）。
  final Future<Uint8List?> Function(String assetId) bytesLoader;

  /// 点击查看（页面负责弹预览层）。
  final VoidCallback? onView;

  const CsAssetAttachmentView({
    super.key,
    required this.asset,
    required this.bytesLoader,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    if (asset.isImage) {
      return CsAssetImageThumb(
        asset: asset,
        bytesLoader: bytesLoader,
        onView: onView,
      );
    }
    return CsAssetFileRow(asset: asset, onView: onView);
  }
}

/// 图片缩略：FutureBuilder 拉授权字节 → Image.memory（含加载/失败占位）。
class CsAssetImageThumb extends StatelessWidget {
  final CsMessageAsset asset;
  final Future<Uint8List?> Function(String assetId) bytesLoader;
  final VoidCallback? onView;

  const CsAssetImageThumb({
    super.key,
    required this.asset,
    required this.bytesLoader,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: bytesLoader(asset.id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return _imagePlaceholder(
            context,
            snapshot.connectionState == ConnectionState.waiting,
          );
        }
        return GestureDetector(
          onTap: onView,
          child: ClipRRect(
            borderRadius: AppRadius.borderRadiusMedium,
            child: Image.memory(
              bytes,
              width: _thumbSize,
              height: _thumbSize,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _imagePlaceholder(context, false),
            ),
          ),
        );
      },
    );
  }

  static const double _thumbSize = 160.0;

  Widget _imagePlaceholder(BuildContext context, bool loading) {
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: AppSizes.iconSizeMedium,
                height: AppSizes.iconSizeMedium,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                CupertinoIcons.photo,
                size: AppSizes.iconSizeLarge,
                color: AppColors.iosGray,
              ),
      ),
    );
  }
}

/// 普通文件行：图标 + 文件名 + 大小（+ 非 active 状态角标）。
class CsAssetFileRow extends StatelessWidget {
  final CsMessageAsset asset;
  final VoidCallback? onView;

  const CsAssetFileRow({super.key, required this.asset, this.onView});

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final name = asset.fileName.isNotEmpty
        ? asset.fileName
        : t.attachUnnamedFile;
    return InkWell(
      onTap: onView,
      borderRadius: AppRadius.borderRadiusMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.tiny,
          vertical: AppSpacing.tiny,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: AppSizes.iconSizeMedium,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.small),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.tiny),
                  Text(
                    asset.isActive
                        ? csFormatAssetSize(asset.sizeBytes)
                        : t.attachStatusUnavailable(
                            size: csFormatAssetSize(asset.sizeBytes),
                          ),
                    maxLines: 1,
                    style: context.textStyle(
                      FontSizeType.caption2,
                      color: AppColors.iosGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
