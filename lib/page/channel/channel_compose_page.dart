import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/upload/batch_upload_controller.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_markdown.dart';
import 'package:imboy/page/channel/widgets/markdown_format.dart';
import 'package:imboy/page/moment/moment_utils.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:image/image.dart' as img;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'channel_provider.dart';

/// 单张图片上传结果：object_key + 原始宽高（供 feed 九宫格布局使用）。
typedef _ImageUpload = ({String uri, int w, int h});

/// 选图函数签名：与 [AssetPicker.pickAssets] 前两个参数对齐（后者多余的可选
/// 命名参数可赋值给本类型，见 Dart 函数子类型规则）。
typedef PickAssetsFn =
    Future<List<AssetEntity>?> Function(
      BuildContext context, {
      AssetPickerConfig pickerConfig,
    });

/// 已选图片的统一抽象：photo_manager 的 [AssetEntity]（非 Android 路径）或
/// 本地文件（Android 绕行路径，file_picker 无 AssetEntity）。预览与上传两用。
class _PickedImage {
  _PickedImage.asset(AssetEntity a) : asset = a, file = null;
  _PickedImage.file(File f) : asset = null, file = f;

  final AssetEntity? asset;
  final File? file;

  bool get isAsset => asset != null;

  /// 预览图：photo_manager 路径用缩略图 provider（防大图 OOM）；文件路径用
  /// ResizeImage 限制解码尺寸（等同缩略图效果）。
  ImageProvider get provider => isAsset
      ? AssetEntityImageProvider(asset!, isOriginal: false)
      : ResizeImage(FileImage(file!), width: 480);

  /// 上传用文件句柄（两条路径最终都落到 [File]）。
  Future<File> fileOf() async {
    if (file != null) return file!;
    final f = await asset!.file;
    if (f == null) throw StateError('asset file unavailable');
    return f;
  }
}

/// 频道「撰写图文」页（公众号式）
///
/// 一次撰写正文 + 多图，统一预览后作为**单条** `channel_imageText` 消息发布，
/// 取代发布栏「每张图独立发送」的即时栏。纯客户端：后端 publish_message 对
/// msgType/payload 透传存储，无需改动。
class ChannelComposePage extends ConsumerStatefulWidget {
  final String channelId;

  /// 选图实现注入点（仅测试用）：默认 null 走 [AssetPicker.pickAssets]。
  /// ponytail: 静态方法不可 mock，函数字段是最低成本接缝；生产恒为 null。
  @visibleForTesting
  final PickAssetsFn? pickAssetsOverride;

  const ChannelComposePage({
    super.key,
    required this.channelId,
    this.pickAssetsOverride,
  });

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

  /// 标题字数到此阈值才显示计数器：平时不占视觉，快满时才提醒。
  static const int _titleCounterThreshold = _maxTitleLength - 15;

  /// 正文上限。原先是散在 build 里的魔法数 2000，与标题常量不对称。
  static const int _maxBodyLength = 2000;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  /// 正文焦点：绑定 TextField，用于「格式工具条」随焦点显示 + 插入后回焦。
  final FocusNode _contentFocusNode = FocusNode();

  /// 正文当前是否获焦——决定格式工具条是否显示（获焦时浮在键盘上方）。
  bool _contentFocused = false;

  final List<_PickedImage> _images = [];
  BatchUploadController<_ImageUpload>? _imageUploadController;

  /// 用户显式标记的封面图；null 时默认取第一张（见 [_effectiveCover]）。
  /// 用对象引用而非下标追踪，避免删图后下标错位。
  _PickedImage? _coverAsset;
  bool _isPublishing = false;

  /// 已成功发布：dispose 时不得再把内容当草稿写回（见 _persistDraftOnExit）。
  bool _published = false;

  /// 生效封面：用户已选则用之，否则退化为第一张（无图则 null）。
  _PickedImage? get _effectiveCover =>
      _coverAsset ?? (_images.isNotEmpty ? _images.first : null);

  @override
  void initState() {
    super.initState();
    _contentFocusNode.addListener(_onContentFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  @override
  void dispose() {
    _imageUploadController?.dispose();
    _persistDraftOnExit();
    _contentFocusNode.removeListener(_onContentFocusChanged);
    _contentFocusNode.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onContentFocusChanged() {
    if (!mounted) return;
    final focused = _contentFocusNode.hasFocus;
    if (focused != _contentFocused) setState(() => _contentFocused = focused);
  }

  String get _draftKey => 'channel_compose_draft_${widget.channelId}';

  void _discardPendingImageUpload() {
    _imageUploadController?.dispose();
    _imageUploadController = null;
  }

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
    // 上限：草稿里的 coverIndex 是只写不读的死字段，封面选择不跨重开保留。
    // 升级触发：图片本身开始持久化（草稿改存 AssetEntity.id 或已上传的
    // object_key，见 _persistDraftOnExit 的 ponytail）时，coverIndex 才有还原
    // 意义，届时一并还原并校验索引是否越界。
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
    // 已发布就别再存了：_publish 成功后 remove(_draftKey) 与 pop() 都是
    // unawaited，pop 触发 dispose 时 controller 里文本还在，会把刚发出去的
    // 内容当草稿写回去——下次进撰写页凭空冒出上一篇。两个异步顺序还不定，
    // 表现为偶发。用标志位比清空 controller 稳。
    if (_published) return;
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
    // Android 上 photo_manager 在部分定制 ROM（华为 Android 9 等）的 platform
    // channel 会挂起：wechat_assets_picker 永远弹不出且无异常、无日志——正是
    // BUG#137「点击无反应」的症状（chat_page 为此已全量绕行 file_picker）。
    // 先短超时探测可用性：挂起/异常走 file_picker（系统原生 Intent）；正常
    // 设备保留 wechat 相册体验（与频道发布栏一致）。override 非空时跳过探测，
    // 保持测试注入走 wechat 路径（widget 测试无真实 platform channel）。
    if (widget.pickAssetsOverride == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !await _photoManagerUsable()) {
      if (!mounted) return;
      await _pickImagesViaFilePicker(remaining);
      return;
    }
    // 探测 await 后可能已离页，wechat 路径使用 context 前统一检查。
    if (!mounted) return;
    try {
      final picker = widget.pickAssetsOverride ?? AssetPicker.pickAssets;
      final assets = await picker(
        context,
        pickerConfig: AssetPickerConfig(
          maxAssets: remaining,
          requestType: RequestType.image,
          textDelegate: const EnglishAssetPickerTextDelegate(),
        ),
      );
      if (assets == null || assets.isEmpty || !mounted) return;
      _discardPendingImageUpload();
      setState(() {
        _images.addAll(assets.map(_PickedImage.asset));
      });
    } catch (e) {
      if (!mounted) return;
      // BUG#137 诊断闭环：真机 Android 9 上本页选图点击无任何反应（无过渡帧、
      // 无崩溃），同进程 channel_detail 发布栏 (RequestType.common) 相册正常。
      // 已核对 wechat_assets_picker 10.1.2 源码：permission 流程在 API<33
      // (PermissionDelegate23) 忽略 requestType；getAssetPathList 对 image 的
      // SQL (MEDIA_TYPE = 1) 干净——两值加载路径等价，未见 image 专属平台缺陷。
      // 此前无 try/catch，release 下异常被 zone 吞掉即「无反应」；此处把真实
      // 异常透出为 toast（与 channel_edit_page 同款「失败 · 真实原因」格式），
      // 下次真机复验若复现，错误文案即根因线索。
      // 无需 dismiss：进入 catch 前没有任何 show()，showError 即终态 toast。
      final reason = e.toString().replaceFirst('Exception: ', '').trim();
      AppLoading.showError(
        reason.isEmpty
            ? t.common.selectImageFailed
            : '${t.common.selectImageFailedWithError} · $reason',
      );
    }
  }

  /// 探测 photo_manager 是否可用：定制 ROM 上 platform channel 挂起时调用
  /// 永不完成且无异常，只能靠超时兜底（正常设备毫秒级返回）。
  Future<bool> _photoManagerUsable() async {
    try {
      await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      ).timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Android 绕行：file_picker 走系统原生 Intent（ACTION_GET_CONTENT），
  /// 完全绕过 photo_manager。选中的本地文件同样进 [_PickedImage] 双轨，
  /// 后续上传/预览与相册路径一致。
  Future<void> _pickImagesViaFilePicker(int remaining) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final picked = <_PickedImage>[
        for (final f in result.files.take(remaining))
          if (f.path != null) _PickedImage.file(File(f.path!)),
      ];
      if (picked.isEmpty) return;
      _discardPendingImageUpload();
      setState(() => _images.addAll(picked));
    } catch (e) {
      if (!mounted) return;
      final reason = e.toString().replaceFirst('Exception: ', '').trim();
      AppLoading.showError(
        reason.isEmpty
            ? t.common.selectImageFailed
            : '${t.common.selectImageFailedWithError} · $reason',
      );
    }
  }

  /// 上传单张图片，返回 object_key + 宽高；失败返回 null 计入失败计数。
  ///
  /// 宽高统一从文件解码：file_picker 路径拿不到 photo_manager 的元数据，
  /// 解码结果与相册路径一致（attachment_handler 同款做法）。
  Future<_ImageUpload?> _uploadImage(File file) async {
    final uri = await _uploadChannelFile(file);
    if (uri == null || uri.isEmpty) return null;
    var width = 0, height = 0;
    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded != null) {
        width = decoded.width;
        height = decoded.height;
      }
    } catch (e) {
      debugPrint('[channel_compose] decodeImage error: $e');
    }
    return (uri: uri, w: width, h: height);
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
      // 频道附件必须标 channel scope：否则默认 private（仅上传者可读），
      // 订阅者渲染时 view_url 授权失败（"无权访问该附件"）。
      scope: 'channel',
      scopeRef: widget.channelId,
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

      await _publishUploadedImages(images, t);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _publishUploadedImages(
    List<Map<String, dynamic>> images,
    Translations t,
  ) async {
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
      _published = true;
      _discardPendingImageUpload();
      unawaited(StorageService.to.remove(_draftKey));
      unawaited(HapticFeedback.lightImpact());
      AppLoading.showSuccess(t.common.tipSuccess);
      context.pop();
    } else {
      AppLoading.showError(t.channel.publishFailed);
    }
  }

  /// 并行上传全部图片；全部成功返回有序 payload 列表，任一失败返回 null。
  /// 无图时返回空列表（纯文字图文合法）。
  Future<List<Map<String, dynamic>>?> _uploadAllImages(Translations t) async {
    if (_images.isEmpty) return const [];

    // 先解析全部本地文件（相册路径的 AssetEntity 也同步落盘句柄），再按
    // _images 顺序批量并发上传（统一走 file 轨道，见 BatchUploadController）。
    final files = <File>[];
    try {
      for (final image in _images) {
        files.add(await image.fileOf());
      }
    } catch (e) {
      debugPrint('[channel_compose] resolve image file error: $e');
      AppLoading.showError(t.common.uploadFailed);
      return null;
    }

    final controller = _imageUploadController ??=
        BatchUploadController<_ImageUpload>(
          fileUploader: (file, _) => _uploadImage(file),
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
      if (controller.items.isEmpty) {
        await controller.addFilesAndUpload(files);
      } else {
        await controller.retryFailed();
      }
    } finally {
      controller.removeListener(onProgress);
      AppLoading.dismiss();
    }
    if (!mounted) return null;

    final failed = controller.items.where((i) => i.isFailed).length;
    if (failed > 0) {
      AppLoading.showError(t.common.uploadPartialFailed(count: failed));
      _showImageUploadRetry(controller, failed, t);
      return null;
    }
    // results 按加入顺序返回，与 _images 顺序一致。
    return [
      for (final r in controller.results) {'uri': r.uri, 'w': r.w, 'h': r.h},
    ];
  }

  void _showImageUploadRetry(
    BatchUploadController<_ImageUpload> controller,
    int failed,
    Translations t,
  ) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.common.uploadPartialFailed(count: failed)),
        action: SnackBarAction(
          label: t.common.buttonRetry,
          onPressed: () => unawaited(_retryImageUpload(controller, t)),
        ),
      ),
    );
  }

  Future<void> _retryImageUpload(
    BatchUploadController<_ImageUpload> controller,
    Translations t,
  ) async {
    if (!mounted ||
        _isPublishing ||
        !identical(_imageUploadController, controller)) {
      return;
    }
    setState(() => _isPublishing = true);
    try {
      await controller.retryFailed();
      if (!mounted) return;
      final failed = controller.items.where((i) => i.isFailed).length;
      if (failed > 0) {
        _showImageUploadRetry(controller, failed, t);
        return;
      }
      final images = [
        for (final r in controller.results) {'uri': r.uri, 'w': r.w, 'h': r.h},
      ];
      await _publishUploadedImages(images, t);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
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
        images: List<_PickedImage>.from(_images),
        cover: _effectiveCover,
        onPublish: _publish,
      ),
    );
  }

  void _setCover(_PickedImage image) {
    HapticFeedback.selectionClick();
    setState(() => _coverAsset = image);
    AppLoading.showToast(context.t.channel.coverSet);
  }

  void _removeImage(int index) {
    _discardPendingImageUpload();
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

    return PopScope(
      // 只在会真丢东西时拦：标题/正文 dispose 时自动存草稿，图片不持久化
      // （见 _persistDraftOnExit 的 ponytail），选了图直接返回就白选了。
      canPop: _images.isEmpty || _isPublishing,
      onPopInvokedWithResult: (didPop, _) => _confirmLeave(didPop),
      child: Scaffold(
        appBar: GlassAppBar(
          title: t.channel.writeArticle,
          automaticallyImplyLeading: true,
          rightDMActions: [
            // 常驻但按内容启停：原先 `if (_hasContent)` 会让按钮凭空出现，
            // 打第一个字时整条 AppBar 跳一下。
            TextButton(
              onPressed: (_hasContent && !_isPublishing) ? _showPreview : null,
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
          child: Column(
            children: [
              Expanded(
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
                        // 不再 counterText:''。标题有 60 字硬上限，藏掉计数后
                        // 打满就静默吞键，用户以为键盘坏了。快到上限才显示，
                        // 平时不占视觉（对标公众号"标题还可输入 N 字"）。
                        counterText:
                            _titleController.text.characters.length >=
                                _titleCounterThreshold
                            ? null
                            : '',
                      ),
                      style: context.textStyle(
                        FontSizeType.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.getIosSeparator(
                        Theme.of(context).brightness,
                      ),
                    ),
                    AppSpacing.verticalSmall,
                    _buildContentField(t),
                    AppSpacing.verticalRegular,
                    _buildImageGrid(),
                  ],
                ),
              ),
              // 格式工具条：正文获焦时浮在键盘上方，只插入 markdown 文本。
              if (_contentFocused && !_isPublishing)
                _MarkdownToolbar(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 返回前确认：已选图片不会随草稿保存，直接退出等于白选。
  Future<void> _confirmLeave(bool didPop) async {
    if (didPop) return;
    final t = context.t;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.channel.composeLeaveImagesLost),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              t.common.confirm,
              style: const TextStyle(color: AppColors.iosRed),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  /// 正文输入框：token 化视觉——聚焦时边框转品牌蓝（原先无边框死灰），
  /// FontSizeType.body + 1.5 行高（随字号设置缩放），圆角框内边距。
  Widget _buildContentField(Translations t) {
    final brightness = Theme.of(context).brightness;
    final separator = AppColors.getIosSeparator(brightness);
    final secondary = AppColors.getTextColor(brightness, isSecondary: true);
    return TextField(
      controller: _contentController,
      focusNode: _contentFocusNode,
      enabled: !_isPublishing,
      maxLength: _maxBodyLength,
      maxLines: null,
      minLines: 6,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: t.channel.articleBodyHint,
        hintStyle: context.textStyle(FontSizeType.body, color: secondary),
        contentPadding: AppSpacing.allMedium,
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusSmall,
          borderSide: BorderSide(color: separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusSmall,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      style: context.textStyle(FontSizeType.body).copyWith(height: 1.5),
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

  Widget _buildImageTile(_PickedImage image, int index, double size) {
    final isCover = identical(image, _effectiveCover);
    // 长按标记封面（订阅号大图卡取此图作封面）。
    return GestureDetector(
      onLongPress: _isPublishing ? null : () => _setCover(image),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: AppRadius.borderRadiusSmall,
            child: Image(
              image: image.provider,
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
            top: 0,
            right: 0,
            // 视觉不变，命中区撑到 44×44（DESIGN.md §13.2）。原先
            // padding:2 + icon:16 只有 ~20×20，缩略图紧挨着极易误删。
            child: Semantics(
              button: true,
              label: context.t.common.delete,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _isPublishing ? null : () => _removeImage(index),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.tiny),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.tiny),
                        decoration: BoxDecoration(
                          color: AppColors.mediaScrimBlack.withValues(
                            alpha: 0.54,
                          ),
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
/// 上限——预览只保证"布局像"，不保证"像素像"：服务端可能对上传图做压缩/裁剪，
/// 预览看到的是原图。
/// 无升级路径（设计约束，非延期）：预览这一刻按定义发生在上传之前，此时只有
/// 本地 AssetEntity、没有 object_key，cachedImageProvider 无从取 URL。把预览
/// 挪到上传之后才能复用远程链路，但那与"发布前预览"的语义矛盾。
class _ComposePreviewSheet extends StatelessWidget {
  final String title;
  final String content;
  final List<_PickedImage> images;

  /// 生效封面（用户标记或默认第一张）；有封面时预览用大图卡样式。
  final _PickedImage? cover;
  final VoidCallback? onPublish;

  const _ComposePreviewSheet({
    required this.title,
    required this.content,
    required this.images,
    required this.cover,
    this.onPublish,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // Spacer to balance close button
              Text(
                context.t.channel.preview,
                style: context.textStyle(
                  FontSizeType.subheadline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
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
          if (content.isNotEmpty) channelMarkdownBody(context, content),
          if (cover == null && images.isNotEmpty) ...[
            AppSpacing.verticalRegular,
            _buildPreviewGrid(context),
          ],
          AppSpacing.verticalLarge,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t.channel.continueEditing),
                ),
              ),
              if (onPublish != null) ...[
                AppSpacing.horizontalMedium,
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onPublish!();
                    },
                    child: Text(context.t.channel.publish),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusSmall,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image(image: cover!.provider, fit: BoxFit.cover),
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
            for (final image in images)
              ClipRRect(
                borderRadius: AppRadius.borderRadiusSmall,
                child: Image(
                  image: image.provider,
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

/// 正文「格式工具条」：一排 markdown 语法快捷按钮（加粗/斜体/删除线/标题/
/// 列表/引用/链接）。每个按钮读 controller 的 text+selection，走 [markdown_format]
/// 的纯函数插入语法后写回，并回焦正文（键盘不收起）。只插入文本，不改 payload。
class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  void _apply(MarkdownEdit Function(String, TextSelection) edit) {
    final v = controller.value;
    final r = edit(v.text, v.selection);
    controller.value = TextEditingValue(text: r.text, selection: r.selection);
    // 回焦：工具条按钮点击后保持正文获焦，避免键盘收起 / 工具条闪隐。
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final brightness = Theme.of(context).brightness;
    final iconColor = AppColors.getTextColor(brightness);
    // (图标, 无障碍标签, 动作)。标题直接插 h2（## ），列表/引用同理走行级前缀。
    // ponytail: 标题不做 h1→h2→h3 循环，直接 h2；需要多级再加。
    final buttons = <(IconData, String, VoidCallback)>[
      (
        Icons.format_bold,
        t.channel.formatBold,
        () => _apply((x, s) => applyInlineWrap(x, s, '**')),
      ),
      (
        Icons.format_italic,
        t.channel.formatItalic,
        () => _apply((x, s) => applyInlineWrap(x, s, '*')),
      ),
      (
        Icons.format_strikethrough,
        t.channel.formatStrikethrough,
        () => _apply((x, s) => applyInlineWrap(x, s, '~~')),
      ),
      (
        Icons.title,
        t.channel.formatHeading,
        () => _apply((x, s) => applyLinePrefix(x, s, '## ')),
      ),
      (
        Icons.format_list_bulleted,
        t.channel.formatList,
        () => _apply((x, s) => applyLinePrefix(x, s, '- ')),
      ),
      (
        Icons.format_quote,
        t.channel.formatQuote,
        () => _apply((x, s) => applyLinePrefix(x, s, '> ')),
      ),
      (
        Icons.link,
        t.channel.formatLink,
        () => _apply(
          (x, s) => applyLink(
            x,
            s,
            linkTextPlaceholder: t.channel.linkTextPlaceholder,
          ),
        ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(brightness),
        border: Border(
          top: BorderSide(color: AppColors.getIosSeparator(brightness)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.symmetricSmall,
        child: Row(
          children: [
            for (final (icon, label, onTap) in buttons)
              IconButton(
                onPressed: onTap,
                icon: Icon(icon, size: 22, color: iconColor),
                tooltip: label,
                // ≥44×44 命中区（DESIGN.md 最小触达）。
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
          ],
        ),
      ),
    );
  }
}
