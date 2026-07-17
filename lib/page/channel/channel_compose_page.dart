import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/upload/batch_upload_controller.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_utils.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'channel_provider.dart';

/// 单张图片上传结果：object_key + 原始宽高（供 feed 九宫格布局使用）。
typedef _ImageUpload = ({String uri, int w, int h});

/// 频道「撰写图文」页（公众号式）
///
/// 一次撰写正文 + 多图，统一预览后作为**单条** `channel_imageText` 消息发布，
/// 取代发布栏「每张图独立发送」的即时栏。纯客户端：后端 publish_message 对
/// msgType/payload 透传存储，无需改动。
class ChannelComposePage extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelComposePage({super.key, required this.channelId});

  @override
  ConsumerState<ChannelComposePage> createState() => _ChannelComposePageState();
}

class _ChannelComposePageState extends ConsumerState<ChannelComposePage> {
  /// 图文最多 9 图（与朋友圈/发布栏一致）。
  static const int _maxImages = 9;

  /// 图片上传单批并发上限（与发布栏一致）。
  /// ponytail: 固定 3，避免大图同批打满带宽；需细粒度限流再升级为信号量池。
  static const int _uploadConcurrency = 3;

  /// 标题字数上限（订阅号式短标题）。
  static const int _maxTitleLength = 60;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final List<AssetEntity> _images = [];

  /// 用户显式标记的封面图；null 时默认取第一张（见 [_effectiveCover]）。
  /// 用对象引用而非下标追踪，避免删图后下标错位。
  AssetEntity? _coverAsset;
  bool _isPublishing = false;

  /// 生效封面：用户已选则用之，否则退化为第一张（无图则 null）。
  AssetEntity? get _effectiveCover =>
      _coverAsset ?? (_images.isNotEmpty ? _images.first : null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  @override
  void dispose() {
    _persistDraftOnExit();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String get _draftKey => 'channel_compose_draft_${widget.channelId}';

  bool get _hasContent =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty ||
      _images.isNotEmpty;

  // ---- 草稿（标题 + 正文 + 封面索引，图片本地资源不落盘）----

  void _restoreDraft() {
    if (!mounted) return;
    final raw = StorageService.to.getString(_draftKey);
    if (raw.isEmpty) return;
    // 新版草稿为 JSON；兼容旧版「仅正文」纯文本草稿。
    // ponytail: coverIndex 不还原——图片未持久化，重开需重选图，还原索引无意义。
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _titleController.text = (data['title'] as String?) ?? '';
        _contentController.text = (data['body'] as String?) ?? '';
      });
    } on FormatException {
      setState(() => _contentController.text = raw);
    }
  }

  void _persistDraftOnExit() {
    final title = _titleController.text.trim();
    final body = _contentController.text.trim();
    if (title.isEmpty && body.isEmpty) {
      unawaited(StorageService.to.remove(_draftKey));
      return;
    }
    // ponytail: 图片本地路径不持久化（重启后 File 可能失效），草稿只存文字类字段
    // + 封面在当前已选图中的索引占位（重开撰写页图片需重选）。不做多草稿箱（二期可选）。
    final coverIndex = _coverAsset == null ? -1 : _images.indexOf(_coverAsset!);
    unawaited(
      StorageService.to.setString(
        _draftKey,
        jsonEncode({'title': title, 'body': body, 'coverIndex': coverIndex}),
      ),
    );
  }

  // ---- 选图 / 删图 ----

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: remaining,
        requestType: RequestType.image,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );
    if (assets == null || assets.isEmpty || !mounted) return;
    setState(() => _images.addAll(assets));
  }

  // ---- 上传 + 发布 ----

  /// 上传单张图片，返回 object_key + 宽高；失败返回 null 计入失败计数。
  Future<_ImageUpload?> _uploadImage(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return null;
    final uri = await _uploadChannelFile(file);
    if (uri == null || uri.isEmpty) return null;
    return (uri: uri, w: asset.width, h: asset.height);
  }

  Future<String?> _uploadChannelFile(File file) async {
    String? uploadedUrl;
    final completer = Completer<bool>();
    await AttachmentApi.uploadFileViaPresignCompat(
      'img',
      file,
      (Map<String, dynamic> resp, String url) {
        if (completer.isCompleted) return;
        if ((resp['status']?.toString() ?? '') == 'ok') {
          uploadedUrl = url;
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      },
      (_) {
        if (!completer.isCompleted) completer.complete(false);
      },
      process: true,
    );
    return (await completer.future) ? uploadedUrl : null;
  }

  Future<void> _publish() async {
    if (_isPublishing || !_hasContent) return;
    setState(() => _isPublishing = true);
    final t = context.t;
    try {
      final images = await _uploadAllImages(t);
      // 上传失败：保留已选图供用户重试（再次点发布），不落库半成品。
      if (images == null) return;

      final title = _titleController.text.trim();
      final coverUri = _resolveCoverUri(images);
      // 向后兼容：title/cover 仅在非空时写入，旧渲染路径（无这两字段）不受影响。
      final payload = <String, dynamic>{
        'images': images,
        if (title.isNotEmpty) 'title': title,
        'cover': ?coverUri,
      };

      final ok = await ref
          .read(channelDetailProvider.notifier)
          .publishMessage(
            content: _contentController.text.trim(),
            msgType: ChannelMessageType.imageText,
            payload: payload,
          );
      if (!mounted) return;
      if (ok) {
        unawaited(StorageService.to.remove(_draftKey));
        unawaited(HapticFeedback.lightImpact());
        AppLoading.showSuccess(t.common.tipSuccess);
        context.pop();
      } else {
        AppLoading.showError(t.channel.publishFailed);
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  /// 并行上传全部图片；全部成功返回有序 payload 列表，任一失败返回 null。
  /// 无图时返回空列表（纯文字图文合法）。
  Future<List<Map<String, dynamic>>?> _uploadAllImages(Translations t) async {
    if (_images.isEmpty) return const [];

    final controller = BatchUploadController<_ImageUpload>(
      uploader: _uploadImage,
      concurrency: _uploadConcurrency,
    );
    void onProgress() {
      final total = controller.length;
      if (total == 0) return;
      final finished = controller.items
          .where((i) => i.isDone || i.isFailed)
          .length;
      AppLoading.showProgress(
        finished / total,
        status: '${t.common.uploading} $finished/$total',
      );
    }

    controller.addListener(onProgress);
    try {
      AppLoading.showProgress(
        0,
        status: '${t.common.uploading} 0/${_images.length}',
      );
      await controller.addAndUpload(_images);
    } finally {
      controller.removeListener(onProgress);
      AppLoading.dismiss();
    }
    if (!mounted) return null;

    final failed = controller.items.where((i) => i.isFailed).length;
    if (failed > 0) {
      AppLoading.showError(t.common.uploadPartialFailed(count: failed));
      return null;
    }
    // results 按加入顺序返回，与 _images 顺序一致。
    return [
      for (final r in controller.results) {'uri': r.uri, 'w': r.w, 'h': r.h},
    ];
  }

  /// 封面 uri：默认第一张，用户显式标记则用之；无图返回 null。
  /// [images] 已上传结果，顺序与 [_images] 一致，故按下标取封面 uri。
  String? _resolveCoverUri(List<Map<String, dynamic>> images) {
    if (images.isEmpty) return null;
    final cover = _coverAsset;
    final idx = cover == null ? 0 : _images.indexOf(cover);
    final safeIdx = (idx >= 0 && idx < images.length) ? idx : 0;
    return images[safeIdx]['uri']?.toString();
  }

  // ---- 预览 ----

  void _showPreview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getSurfaceColor(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ComposePreviewSheet(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        images: List<AssetEntity>.from(_images),
        cover: _effectiveCover,
      ),
    );
  }

  void _setCover(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() => _coverAsset = asset);
    AppLoading.showToast(context.t.channel.coverSet);
  }

  void _removeImage(int index) {
    setState(() {
      final removed = _images.removeAt(index);
      // 移除的正是显式封面 → 清空标记，回退默认第一张。
      if (identical(removed, _coverAsset)) _coverAsset = null;
    });
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final canPublish = _hasContent && !_isPublishing;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.writeArticle,
        automaticallyImplyLeading: true,
        rightDMActions: [
          if (_hasContent)
            TextButton(
              onPressed: _isPublishing ? null : _showPreview,
              child: Text(t.channel.preview),
            ),
          TextButton(
            onPressed: canPublish ? _publish : null,
            child: _isPublishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.channel.publish),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.allRegular,
          children: [
            TextField(
              controller: _titleController,
              enabled: !_isPublishing,
              maxLength: _maxTitleLength,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t.channel.titleOptional,
                border: InputBorder.none,
                counterText: '',
              ),
              style: context.textStyle(
                FontSizeType.title,
                fontWeight: FontWeight.w600,
              ),
            ),
            Divider(
              height: 1,
              color: AppColors.getIosSeparator(Theme.of(context).brightness),
            ),
            AppSpacing.verticalSmall,
            TextField(
              controller: _contentController,
              enabled: !_isPublishing,
              maxLength: 2000,
              maxLines: null,
              minLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t.channel.writeMessage,
                border: InputBorder.none,
              ),
              style: TextStyle(fontSize: FontSizeType.body.size, height: 1.5),
            ),
            AppSpacing.verticalRegular,
            _buildImageGrid(),
          ],
        ),
      ),
    );
  }

  // ponytail: 只做删除 + 追加，不做长按拖拽排序。pubspec 无 reorderable_grid /
  // flutter_reorderable_grid_view 依赖，Flutter 自带 ReorderableListView 不适配
  // 横向网格。需要排序时再引依赖或实现自绘拖拽。
  Widget _buildImageGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.small;
        final layout = momentGridLayout(
          count: _images.length,
          maxWidth: constraints.maxWidth,
          spacing: spacing,
        );
        final cell = layout.cellSize;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < _images.length; i++)
              _buildImageTile(_images[i], i, cell),
            if (_images.length < _maxImages) _buildAddTile(cell),
          ],
        );
      },
    );
  }

  Widget _buildImageTile(AssetEntity asset, int index, double size) {
    final isCover = identical(asset, _effectiveCover);
    // 长按标记封面（订阅号大图卡取此图作封面）。
    return GestureDetector(
      onLongPress: _isPublishing ? null : () => _setCover(asset),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: AppRadius.borderRadiusSmall,
            child: Image(
              image: AssetEntityImageProvider(asset, isOriginal: false),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          if (isCover)
            Positioned(
              left: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.85),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Text(
                  context.t.channel.coverLabel,
                  style: context.textStyle(
                    FontSizeType.tiny,
                    color: AppColors.mediaScrimWhite,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: _isPublishing ? null : () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.mediaScrimBlack.withValues(alpha: 0.54),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.mediaScrimWhite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTile(double size) {
    final separator = AppColors.getIosSeparator(Theme.of(context).brightness);
    return GestureDetector(
      onTap: _isPublishing ? null : _pickImages,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: separator, width: 1),
          borderRadius: AppRadius.borderRadiusSmall,
        ),
        child: Tooltip(
          message: context.t.channel.addImage,
          child: Icon(Icons.add, size: 32, color: separator),
        ),
      ),
    );
  }
}

/// 发布前预览：仿阅读页布局的所见即所得——标题 + 封面大图/九宫格 + 完整正文，
/// 让作者发布前看到进 feed 与阅读页大概长啥样。
///
/// ponytail: 图片尚未上传，预览直接用 AssetEntityImage 渲染本地资源，
/// 不复用 feed 的 cachedImageProvider（那走远程 object_key）。
class _ComposePreviewSheet extends StatelessWidget {
  final String title;
  final String content;
  final List<AssetEntity> images;

  /// 生效封面（用户标记或默认第一张）；有封面时预览用大图卡样式。
  final AssetEntity? cover;

  const _ComposePreviewSheet({
    required this.title,
    required this.content,
    required this.images,
    required this.cover,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getTextColor(Theme.of(context).brightness);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: AppSpacing.allRegular,
        children: [
          Center(
            child: Text(
              context.t.channel.preview,
              style: context.textStyle(
                FontSizeType.subheadline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          AppSpacing.verticalRegular,
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: context.textStyle(
                FontSizeType.title,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalSmall,
          ],
          // 有封面 → 顶部封面大图（对齐阅读页/大图卡）；否则九宫格。
          if (cover != null) _buildCover(context),
          if (cover != null && content.isNotEmpty) AppSpacing.verticalRegular,
          if (content.isNotEmpty)
            Text(
              content,
              style: TextStyle(
                fontSize: FontSizeType.body.size,
                height: 1.5,
                color: textColor,
              ),
            ),
          if (cover == null && images.isNotEmpty) ...[
            AppSpacing.verticalRegular,
            _buildPreviewGrid(context),
          ],
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusSmall,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image(
          image: AssetEntityImageProvider(cover!, isOriginal: false),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPreviewGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.small;
        final layout = momentGridLayout(
          count: images.length,
          maxWidth: constraints.maxWidth,
          spacing: spacing,
        );
        final cell = layout.cellSize;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final asset in images)
              ClipRRect(
                borderRadius: AppRadius.borderRadiusSmall,
                child: Image(
                  image: AssetEntityImageProvider(asset, isOriginal: false),
                  width: cell,
                  height: cell,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        );
      },
    );
  }
}
