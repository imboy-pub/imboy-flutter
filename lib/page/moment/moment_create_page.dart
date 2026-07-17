import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/chat/composer_field.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/upload/batch_upload_controller.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/application/moment_facade.dart';
import 'package:imboy/page/moment/moment_friend_picker/moment_friend_picker_page.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'moment_interactions.dart';
import 'moment_utils.dart';

/// 朋友圈发布页 - 沉浸式重构（对标微信朋友圈发布体验）
class MomentCreatePage extends StatefulWidget {
  const MomentCreatePage({super.key});

  @override
  State<MomentCreatePage> createState() => _MomentCreatePageState();
}

class _MomentCreatePageState extends State<MomentCreatePage> {
  final MomentFacade _api = MomentFacade.instance;
  MediaPickerCapability get _picker =>
      CapabilityLocator.I.get<MediaPickerCapability>();

  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _allowUidsController = TextEditingController();
  final TextEditingController _denyUidsController = TextEditingController();

  /// 逐项上传状态：相册批量选中与相机即拍的每项各自流转
  /// pending→uploading→done/failed，本地缩略图即时可见，失败项单独重试
  /// 不影响其余成功项。concurrency=momentMaxImageCount(9) 等价于原
  /// Future.wait 全并行（朋友圈上限）。
  late final BatchUploadController<Map<String, dynamic>> _uploads =
      BatchUploadController<Map<String, dynamic>>(
        uploader: _uploadAsset,
        fileUploader: _uploadCapturedFile,
        concurrency: momentMaxImageCount,
      );

  int _visibility = momentVisibilityFriends;
  bool _allowComment = true;
  bool _isSubmitting = false;

  /// 上传进行中仅禁用发布（防止半图发帖）；继续追加媒体不受影响。
  bool get _busy => _uploads.isBusy;

  String get _draftKey => momentFailedDraftKey(UserRepoLocal.to.currentUid);

  @override
  void initState() {
    super.initState();
    _uploads.addListener(_onUploadsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestoreDraft());
  }

  void _onUploadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _uploads.removeListener(_onUploadsChanged);
    _uploads.dispose();
    _contentController.dispose();
    _allowUidsController.dispose();
    _denyUidsController.dispose();
    super.dispose();
  }

  void _tryRestoreDraft() {
    final key = _draftKey;
    if (key.isEmpty) {
      _restoreLastVisibility();
      return;
    }
    final raw = StorageService.getMap(key);
    final draft = restoreMomentDraft(raw);
    if (draft == null) {
      // 无发布失败草稿可恢复时，退化为「记住上次可见性」（P1-1）。
      _restoreLastVisibility();
      return;
    }
    if (!mounted) return;
    setState(() {
      _contentController.text = draft.content;
      _visibility = draft.visibility;
      _allowUidsController.text = draft.allowUids.join(',');
      _denyUidsController.text = draft.denyUids.join(',');
    });
    AppLoading.showInfo(context.t.discovery.momentsDraftRestored);
  }

  /// 记住上次发布使用的可见性 storage key（账号隔离，与 `_draftKey` 同构）。
  String get _lastVisibilityKey {
    final uid = UserRepoLocal.to.currentUid.trim();
    if (uid.isEmpty) return '';
    return 'moment_last_visibility_$uid';
  }

  /// P1-1：再次进入发布页时默认带出上次可见性设置（无草稿时才生效）。
  void _restoreLastVisibility() {
    final key = _lastVisibilityKey;
    if (key.isEmpty) return;
    final raw = StorageService.getMap(key);
    if (raw.isEmpty) return;
    final rawVisibility = raw['visibility'];
    if (rawVisibility is! int) return;
    if (!mounted) return;
    setState(() {
      _visibility = parseMomentVisibility({'visibility': rawVisibility});
      final allow = raw['allow_uids'];
      if (allow is List) {
        _allowUidsController.text = allow.whereType<String>().join(',');
      }
      final deny = raw['deny_uids'];
      if (deny is List) {
        _denyUidsController.text = deny.whereType<String>().join(',');
      }
    });
  }

  /// 持久化本次确认的可见性设置，供下次进入发布页默认带出。
  Future<void> _saveLastVisibility(MomentVisibilityResult result) async {
    final key = _lastVisibilityKey;
    if (key.isEmpty) return;
    await StorageService.setMap(key, <String, dynamic>{
      'visibility': result.visibility,
      'allow_uids': result.allowUids,
      'deny_uids': result.denyUids,
    });
  }

  Future<void> _saveFailedDraft(String content) async {
    final key = _draftKey;
    if (key.isEmpty) return;
    final mediaUrls = _uploads.results
        .map((m) => parseModelString(m['url']))
        .where((u) => u.isNotEmpty)
        .toList(growable: false);
    final map = buildMomentDraft(
      content: content,
      mediaUrls: mediaUrls,
      visibility: _visibility,
      allowUids: momentVisibilityRequiresAllowUids(_visibility)
          ? parseMomentUidList(_allowUidsController.text)
          : const [],
      denyUids: momentVisibilityRequiresDenyUids(_visibility)
          ? parseMomentUidList(_denyUidsController.text)
          : const [],
      savedAt: DateTime.now(),
    );
    await StorageService.setMap(key, map);
  }

  Future<void> _clearDraft() async {
    final key = _draftKey;
    if (key.isEmpty) return;
    await StorageService.to.remove(key);
  }

  bool get _hasUnsavedContent =>
      _contentController.text.trim().isNotEmpty || _uploads.length > 0;

  Future<void> _confirmExit(bool didPop) async {
    if (didPop) return;
    if (!_hasUnsavedContent) {
      Navigator.of(context).pop();
      return;
    }
    final keep = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.t.discovery.momentsDraftKeepTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(context.t.discovery.momentsDraftKeepMessage),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(context.t.discovery.momentActionCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.t.discovery.momentsDraftDiscard),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.t.discovery.momentsDraftKeep),
          ),
        ],
      ),
    );
    if (!mounted || keep == null) return;
    if (keep) {
      await _saveFailedDraft(_contentController.text.trim());
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<String?> _uploadFile(String prefix, File file) async {
    final completer = Completer<String?>();
    await AttachmentApi.uploadFileViaPresignCompat(
      prefix,
      file,
      (Map<String, dynamic> resp, String url) {
        if (completer.isCompleted) return;
        final status = parseModelString(resp['status']);
        if (status == 'ok' && url.isNotEmpty) {
          completer.complete(url);
          return;
        }
        completer.complete(null);
      },
      (_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
      process: true,
      // scope='moment'：发帖前上传时 momentId 未生成，scope_ref 留空，
      // 后端 create_post 成功后按 object_key 回填 scope_ref=momentId。
      // 此前默认 private 导致除作者外查看动态图片/视频全 403 碎图。
      scope: 'moment',
    );
    return completer.future;
  }

  /// 相机即拍与相册项统一走逐项机制：入网格即见本地缩略图 + 上传进度，
  /// 失败留在网格可单独重试，不再「转圈占位 + 失败即丢照片」。
  Future<void> _pickImage({bool useCamera = false}) async {
    if (_uploads.length >= momentMaxImageCount) return;
    final media = useCamera
        ? await _picker.pickCamera(context)
        : await _picker.pickSingle(context, MediaType.image);
    if (media == null || !mounted) return;

    await _uploads.addFileAndUpload(File(media.path));
    if (!mounted) return;
    if (_uploads.hasFailed) {
      AppLoading.showError(context.t.common.momentsUploadFailed);
    }
  }

  Future<void> _pickVideo({bool useCamera = false}) async {
    if (_uploads.length >= momentMaxImageCount) return;
    // 修复：拍摄视频此前误调 pickSingle(gallery)，从未真正唤起相机。
    // useCamera 时走 pickCamera(enableRecording: true) 唤起原生相机录像。
    final media = useCamera
        ? await _picker.pickCamera(context, enableRecording: true)
        : await _picker.pickSingle(context, MediaType.video);
    if (media == null || !mounted) return;

    await _uploads.addFileAndUpload(File(media.path), isVideo: true);
    if (!mounted) return;
    if (_uploads.hasFailed) {
      AppLoading.showError(context.t.common.momentsUploadFailed);
    }
  }

  /// 相册多选网格（P0-2）：图/视频混选一次批量传，替代原 4 项 ActionSheet
  /// 里「从相册选图」+「选择视频」两个单选入口。
  ///
  /// `SpecialPickerType.wechatMoment` 是 wechat_assets_picker 自带的朋友圈
  /// 模式：选择器内部已强制「多图 或 单视频」互斥，与 [validateMediaSelection]
  /// 的规则一致（后者仍作为提交前的最终防线保留，覆盖跨批次叠加的场景）。
  Future<void> _pickMediaFromAlbum() async {
    if (_uploads.length >= momentMaxImageCount) return;
    // 剩余可选额度而非固定 momentMaxImageCount：避免多轮选择后总数超限。
    final remaining = momentMaxImageCount - _uploads.length;
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: remaining,
        requestType: RequestType.common,
        specialPickerType: SpecialPickerType.wechatMoment,
      ),
    );
    if (assets == null || assets.isEmpty || !mounted) return;

    // 逐张占位入网格 + 并行上传（controller 内部 Future.wait）；失败项保留
    // 为可重试态，成功项不受影响。逐项状态经 listener 驱动网格刷新。
    await _uploads.addAndUpload(assets);
    if (!mounted) return;
    if (_uploads.hasFailed) {
      AppLoading.showError(context.t.common.momentsUploadFailed);
    }
  }

  /// 相机即拍 File 项的上传路由（BatchUploadController.fileUploader）：
  /// 录像走视频三件套，拍照走图片直传。失败返回 null，项留网格可重试。
  Future<Map<String, dynamic>?> _uploadCapturedFile(
    File file,
    bool isVideo,
  ) async {
    if (isVideo) {
      return _uploadVideoFile(file);
    }
    final url = await _uploadFile('img', file);
    if (url == null || url.isEmpty) return null;
    return <String, dynamic>{'type': 'image', 'url': url};
  }

  /// 单个选中资源的上传路由：图片走 `_uploadFile`，视频走 `_uploadVideoFile`。
  /// 失败返回 null，调用方用 `whereType` 过滤，不阻塞其余成功项。
  Future<Map<String, dynamic>?> _uploadAsset(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return null;
    if (asset.type == AssetType.video) {
      return _uploadVideoFile(file);
    }
    final url = await _uploadFile('img', file);
    if (url == null || url.isEmpty) return null;
    return <String, dynamic>{'type': 'image', 'url': url};
  }

  /// 视频上传三件套（原视频/缩略图/时长逻辑，从 `_pickVideo` 抽出复用）。
  Future<Map<String, dynamic>?> _uploadVideoFile(File file) async {
    final url = await _uploadFile('video', file);
    if (url == null || url.isEmpty) return null;

    String coverUrl = '';
    int durationMs = 0;
    try {
      final thumb = await VideoCompress.getFileThumbnail(
        file.path,
        quality: 60,
        position: -1,
      );
      final uploadedCover = await _uploadFile('img', thumb);
      coverUrl = uploadedCover ?? '';
      final mediaInfo = await VideoCompress.getMediaInfo(file.path);
      durationMs = (mediaInfo.duration ?? 0).toInt();
    } on Exception {
      coverUrl = '';
      durationMs = 0;
    }

    return <String, dynamic>{
      'type': 'video',
      'url': url,
      'cover_url': coverUrl,
      'duration_ms': durationMs,
    };
  }

  void _removeMedia(int index) => _uploads.removeAt(index);

  /// 复用失败项的 AssetEntity 单独重传，不影响其余成功项。
  void _retryUpload(int index) => unawaited(_uploads.retry(index));

  Future<void> _submit() async {
    if (_isSubmitting || _busy) return;
    final content = _contentController.text.trim();
    final media = _uploads.results;
    // 有上传失败的媒体时先拦下，避免静默丢图：用户需重试或移除后再发布。
    if (_uploads.hasFailed) {
      AppLoading.showInfo(context.t.common.momentsHasFailedUploads);
      return;
    }
    if (content.isEmpty && media.isEmpty) {
      AppLoading.showInfo(context.t.common.momentsContentOrMediaRequired);
      return;
    }

    final validation = validateMediaSelection(media);
    if (!validation.ok) {
      final t = context.t;
      final msg = switch (validation.error) {
        momentMediaErrorTooManyImages => t.chat.momentsMediaTooManyImages,
        momentMediaErrorTooManyVideos => t.chat.momentsMediaTooManyVideos,
        momentMediaErrorMixed => t.chat.momentsMediaMixedImageAndVideo,
        _ => t.common.momentsPublishFailed,
      };
      AppLoading.showInfo(msg);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    final created = await _api.createPost(
      content: content,
      media: media,
      visibility: _visibility,
      allowComment: _allowComment,
      allowUids: momentVisibilityRequiresAllowUids(_visibility)
          ? parseMomentUidList(_allowUidsController.text)
          : const [],
      denyUids: momentVisibilityRequiresDenyUids(_visibility)
          ? parseMomentUidList(_denyUidsController.text)
          : const [],
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (created == null) {
      await _saveFailedDraft(content);
      if (!mounted) return;
      AppLoading.showError(context.t.common.momentsPublishFailed);
      return;
    }

    await _clearDraft();
    if (!mounted) return;
    final momentId = parseModelString(created['id']);
    AppEventBus.fire(
      MomentTimelineChangedEvent(
        action: 'moment_new',
        momentId: momentId,
        payload: created,
      ),
    );
    Navigator.of(context).pop(true);
  }

  /// P0-2：相册项改为统一多选网格（`_pickMediaFromAlbum`），一次选中即批量
  /// 并行上传；拍照/拍视频入口保留（原相机链路不变，只是从 4 项收到 3 项）。
  void _showMediaPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickMediaFromAlbum();
            },
            child: Text(context.t.main.selectFromAlbum),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickImage(useCamera: true);
            },
            child: Text(context.t.main.takePhoto),
          ),
          // 修复：拍摄视频真正唤起相机录像（pickCamera enableRecording）
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickVideo(useCamera: true);
            },
            child: Text(context.t.chat.momentsRecordVideo),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.t.discovery.momentActionCancel),
        ),
      ),
    );
  }

  /// 可见性选择：三种无名单态（公开/仅好友/仅自己）原地 ActionSheet 选中即定，
  /// 不跳页、不拉好友(SQLite)/标签(网络)；仅「部分可见/不给谁看」才跳好友名单页。
  void _pickVisibility() {
    final t = context.t;
    final options = <(int, String)>[
      (momentVisibilityPublic, t.discovery.momentsVisibilityPublic),
      (momentVisibilityFriends, t.contact.momentsVisibilityFriends),
      (momentVisibilityPrivate, t.chat.momentsVisibilityPrivate),
      (momentVisibilityAllowList, t.discovery.momentsVisibilityPartial),
      (momentVisibilityDenyList, t.discovery.momentsVisibilityExclude),
    ];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (final o in options)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _onVisibilityOptionTap(o.$1);
              },
              child: Text(o.$2),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.discovery.momentActionCancel),
        ),
      ),
    );
  }

  /// 无名单态原地更新并记忆；名单两态才跳好友名单页。
  void _onVisibilityOptionTap(int visibility) {
    if (momentVisibilityNeedsFriendList(visibility)) {
      unawaited(_pushFriendPicker(visibility));
      return;
    }
    setState(() => _visibility = visibility);
    unawaited(
      _saveLastVisibility(
        MomentVisibilityResult(
          visibility: visibility,
          allowUids: parseMomentUidList(_allowUidsController.text),
          denyUids: parseMomentUidList(_denyUidsController.text),
        ),
      ),
    );
  }

  /// 「部分可见/不给谁看」跳好友名单页做多选；确认后回填并记住本次设置。
  Future<void> _pushFriendPicker(int visibility) async {
    final result = await Navigator.of(context).push<MomentVisibilityResult>(
      CupertinoPageRoute<MomentVisibilityResult>(
        builder: (_) => MomentFriendPickerPage(
          initialVisibility: visibility,
          initialAllowUids: parseMomentUidList(_allowUidsController.text),
          initialDenyUids: parseMomentUidList(_denyUidsController.text),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _visibility = result.visibility;
      _allowUidsController.text = result.allowUids.join(',');
      _denyUidsController.text = result.denyUids.join(',');
    });
    await _saveLastVisibility(result);
  }

  /// 可见性摘要文案：基础标签 + 命中名单模式时附加已选人数。
  String _visibilitySummary(Translations t) {
    final base = momentVisibilityLabel(_visibility, t);
    if (momentVisibilityRequiresAllowUids(_visibility)) {
      final count = parseMomentUidList(_allowUidsController.text).length;
      if (count <= 0) return base;
      return '$base · ${t.momentFriendPicker.selectedCount(count: count)}';
    }
    if (momentVisibilityRequiresDenyUids(_visibility)) {
      final count = parseMomentUidList(_denyUidsController.text).length;
      if (count <= 0) return base;
      return '$base · ${t.momentFriendPicker.selectedCount(count: count)}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PopScope(
      canPop: !_hasUnsavedContent,
      onPopInvokedWithResult: (didPop, _) => _confirmExit(didPop),
      child: Scaffold(
        appBar: CupertinoNavigationBar(
          middle: Text(t.chat.momentsSend),
          trailing: _isSubmitting
              ? const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: CupertinoActivityIndicator(radius: 10),
                )
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    t.common.confirm,
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  ComposerField(
                    controller: _contentController,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 5000,
                    warnThreshold: 4500,
                    hintText: t.discovery.momentContentPlaceholder,
                  ),
                  AppSpacing.verticalMedium,
                  _buildMediaGrid(t),
                ],
              ),
            ),
            _buildToolbar(t),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(Translations t) {
    final items = _uploads.items;
    final showAdd = items.length < momentMaxImageCount;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 复用统一的 cell 尺寸计算；拾取网格（含"+添加"格）始终三列流式排布
        final layout = momentGridLayout(
          count: items.length + (showAdd ? 1 : 0),
          maxWidth: constraints.maxWidth,
          spacing: AppSpacing.small,
        );
        return Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            ...List.generate(items.length, (index) {
              final item = items[index];
              return _MediaThumb(
                size: layout.cellSize,
                item: item,
                onRemove: () => _removeMedia(index),
                onRetry: item.canRetry ? () => _retryUpload(index) : null,
              );
            }),
            if (showAdd)
              _MediaAddButton(size: layout.cellSize, onTap: _showMediaPicker),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(Translations t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: AppColors.getIosSeparator(
              Theme.of(context).brightness,
            ).withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _ToolbarItem(
              icon: CupertinoIcons.lock_fill,
              label: t.discovery.momentsVisibility,
              value: _visibilitySummary(t),
              onTap: _pickVisibility,
            ),
            _ToolbarSwitch(
              icon: CupertinoIcons.chat_bubble_fill,
              label: t.common.momentsAllowComment,
              value: _allowComment,
              onChanged: (v) => setState(() => _allowComment = v),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个媒体缩略图，按逐项上传状态渲染（本地缩略图优先，见 `_buildImage`）：
/// - done：本地缩略图（视频叠播放角标；录像文件回退网络封面）
/// - uploading/pending：本地缩略图 + 转圈遮罩
/// - failed：本地缩略图 + 「重试」角标（点击复用 AssetEntity/File 重传）
class _MediaThumb extends StatelessWidget {
  final double size;
  final UploadItem<Map<String, dynamic>> item;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  const _MediaThumb({
    required this.size,
    required this.item,
    required this.onRemove,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final result = item.result;
    final previewUrl = result == null ? '' : pickMediaPreviewUrl(result);
    final isVideo =
        result != null && parseModelString(result['type']) == 'video';
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusMedium,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceContainer
                : AppColors.lightSurfaceContainer,
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildImage(context, previewUrl),
        ),
        if (isVideo && item.isDone)
          const Positioned.fill(
            child: Center(
              child: Icon(
                CupertinoIcons.play_circle_fill,
                color: AppColors.onPrimary,
                size: 26,
              ),
            ),
          ),
        if (item.isUploading || item.isPending)
          const Positioned.fill(
            child: _ThumbOverlay(
              child: CupertinoActivityIndicator(color: AppColors.onPrimary),
            ),
          ),
        if (item.isFailed)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: _ThumbOverlay(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.arrow_clockwise,
                      size: 22,
                      color: AppColors.onPrimary,
                    ),
                    Text(
                      context.t.common.buttonRetry,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.darkBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.tiny),
                ),
              ),
              child: const Icon(
                CupertinoIcons.xmark,
                size: 14,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 本地源优先：相册项用 AssetEntity 缩略图、相机照片用 Image.file——
  /// 全程即时可见且 done 后免网络重载；仅无本地图的场景（录像文件无法
  /// Image.file 预览）才回退网络封面/图标占位。
  Widget _buildImage(BuildContext context, String previewUrl) {
    final asset = item.asset;
    if (asset != null) {
      return Image(
        image: AssetEntityImageProvider(asset, isOriginal: false),
        fit: BoxFit.cover,
      );
    }
    final file = item.file;
    if (file != null && !item.isVideoFile) {
      // cacheWidth 按 cell 物理像素解码，避免相机原图全尺寸驻留内存。
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      );
    }
    if (previewUrl.isNotEmpty) {
      return Image(image: cachedImageProvider(previewUrl), fit: BoxFit.cover);
    }
    if (item.isVideoFile) {
      // 录像上传中/失败：无本地缩略图，用视频图标占位。
      return const Center(
        child: Icon(
          CupertinoIcons.videocam_fill,
          size: 30,
          color: AppColors.iosGray,
        ),
      );
    }
    return const Icon(Icons.broken_image_outlined);
  }
}

/// 缩略图上的半透明深色遮罩，居中承载转圈或重试角标。
class _ThumbOverlay extends StatelessWidget {
  final Widget child;
  const _ThumbOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkBackground.withValues(alpha: 0.45),
      child: Center(child: child),
    );
  }
}

class _MediaAddButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  const _MediaAddButton({required this.size, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderRadiusMedium,
          color: AppColors.iosGray.withValues(alpha: 0.12),
        ),
        child: const Center(
          child: Icon(CupertinoIcons.add, size: 30, color: AppColors.iosGray),
        ),
      ),
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _ToolbarItem({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.wechatBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: context.textStyle(
                  FontSizeType.normal,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.iosGray,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.iosGray3,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToolbarSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.wechatBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.normal,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
