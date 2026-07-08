import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/app_loading.dart';
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

import 'moment_interactions.dart';

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

  final List<Map<String, dynamic>> _media = [];

  int _visibility = momentVisibilityFriends;
  bool _allowComment = true;
  bool _isUploading = false;
  bool _isSubmitting = false;

  String get _draftKey => momentFailedDraftKey(UserRepoLocal.to.currentUid);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryRestoreDraft());
  }

  @override
  void dispose() {
    _contentController.dispose();
    _allowUidsController.dispose();
    _denyUidsController.dispose();
    super.dispose();
  }

  void _tryRestoreDraft() {
    final key = _draftKey;
    if (key.isEmpty) return;
    final raw = StorageService.getMap(key);
    final draft = restoreMomentDraft(raw);
    if (draft == null) return;
    if (!mounted) return;
    setState(() {
      _contentController.text = draft.content;
      _visibility = draft.visibility;
      _allowUidsController.text = draft.allowUids.join(',');
      _denyUidsController.text = draft.denyUids.join(',');
    });
    AppLoading.showInfo(context.t.discovery.momentsDraftRestored);
  }

  Future<void> _saveFailedDraft(String content) async {
    final key = _draftKey;
    if (key.isEmpty) return;
    final mediaUrls = _media
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
      _contentController.text.trim().isNotEmpty || _media.isNotEmpty;

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
    );
    return completer.future;
  }

  Future<void> _pickImage({bool useCamera = false}) async {
    if (_isUploading || _media.length >= momentMaxImageCount) return;
    final media = useCamera
        ? await _picker.pickCamera(context)
        : await _picker.pickSingle(context, MediaType.image);
    if (media == null || !mounted) return;

    setState(() {
      _isUploading = true;
    });
    final url = await _uploadFile('img', File(media.path));
    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (url != null && url.isNotEmpty) {
        _media.add(<String, dynamic>{'type': 'image', 'url': url});
      }
    });
    if (url == null || url.isEmpty) {
      AppLoading.showError(context.t.common.momentsUploadFailed);
    }
  }

  Future<void> _pickVideo({bool useCamera = false}) async {
    if (_isUploading || _media.length >= momentMaxImageCount) return;
    // 修复：拍摄视频此前误调 pickSingle(gallery)，从未真正唤起相机。
    // useCamera 时走 pickCamera(enableRecording: true) 唤起原生相机录像。
    final media = useCamera
        ? await _picker.pickCamera(context, enableRecording: true)
        : await _picker.pickSingle(context, MediaType.video);
    if (media == null || !mounted) return;

    setState(() {
      _isUploading = true;
    });
    final file = File(media.path);
    final url = await _uploadFile('video', file);

    String coverUrl = '';
    int durationMs = 0;
    try {
      final thumb = await VideoCompress.getFileThumbnail(
        media.path,
        quality: 60,
        position: -1,
      );
      final uploadedCover = await _uploadFile('img', thumb);
      coverUrl = uploadedCover ?? '';
      final mediaInfo = await VideoCompress.getMediaInfo(media.path);
      durationMs = (mediaInfo.duration ?? 0).toInt();
    } on Exception {
      coverUrl = '';
      durationMs = 0;
    }

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (url != null && url.isNotEmpty) {
        _media.add(<String, dynamic>{
          'type': 'video',
          'url': url,
          'cover_url': coverUrl,
          'duration_ms': durationMs,
        });
      }
    });
    if (url == null || url.isEmpty) {
      AppLoading.showError(context.t.common.momentsUploadFailed);
    }
  }

  void _removeMedia(int index) {
    if (index < 0 || index >= _media.length) return;
    setState(() {
      _media.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isUploading) return;
    final content = _contentController.text.trim();
    if (content.isEmpty && _media.isEmpty) {
      AppLoading.showInfo(context.t.common.momentsContentOrMediaRequired);
      return;
    }

    final validation = validateMediaSelection(_media);
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
      media: _media,
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

  Future<void> _pickUids({
    required TextEditingController controller,
    required String title,
  }) async {
    final initial = parseMomentUidList(controller.text);
    final result = await Navigator.of(context).push<List<String>>(
      CupertinoPageRoute<List<String>>(
        builder: (_) =>
            MomentFriendPickerPage(title: title, initialSelectedUids: initial),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      controller.text = result.join(',');
    });
  }

  void _showMediaPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickImage();
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
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _pickVideo();
            },
            child: Text(context.t.chat.momentsSelectVideo),
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

  void _showVisibilityPicker() {
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
        actions: options
            .map(
              (o) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _visibility = o.$1);
                },
                child: Text(o.$2),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.discovery.momentActionCancel),
        ),
      ),
    );
  }

  String get _visibilityLabel => momentVisibilityLabel(_visibility, context.t);

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
                  onPressed: _isUploading ? null : _submit,
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
                  TextField(
                    controller: _contentController,
                    autofocus: true,
                    maxLines: 8,
                    minLines: 4,
                    maxLength: 5000,
                    decoration: InputDecoration(
                      hintText: t.discovery.momentContentPlaceholder,
                      hintStyle: context.textStyle(
                        FontSizeType.body,
                        color: AppColors.iosGray3,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    style: context
                        .textStyle(FontSizeType.body)
                        .copyWith(height: 1.5),
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
    final cellSize = (MediaQuery.of(context).size.width - 40 - 16) / 3;
    final showAdd = _media.length < momentMaxImageCount && !_isUploading;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...List.generate(_media.length, (index) {
          final media = _media[index];
          final type = parseModelString(media['type']);
          final previewUrl = pickMediaPreviewUrl(media);
          return _MediaThumb(
            size: cellSize,
            isVideo: type == 'video',
            previewUrl: previewUrl,
            onRemove: () => _removeMedia(index),
          );
        }),
        if (_isUploading) _MediaUploadingPlaceholder(size: cellSize),
        if (showAdd) _MediaAddButton(size: cellSize, onTap: _showMediaPicker),
      ],
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
              value: _visibilityLabel,
              onTap: _showVisibilityPicker,
            ),
            if (momentVisibilityRequiresAllowUids(_visibility))
              _buildUidRow(
                controller: _allowUidsController,
                title: t.momentFriendPicker.titleAllow,
              ),
            if (momentVisibilityRequiresDenyUids(_visibility))
              _buildUidRow(
                controller: _denyUidsController,
                title: t.momentFriendPicker.titleDeny,
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

  Widget _buildUidRow({
    required TextEditingController controller,
    required String title,
  }) {
    final count = parseMomentUidList(controller.text).length;
    return _ToolbarItem(
      icon: CupertinoIcons.person_2_fill,
      label: title,
      value: count > 0
          ? context.t.momentFriendPicker.selectedCount(count: count)
          : null,
      onTap: () => _pickUids(controller: controller, title: title),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  final double size;
  final bool isVideo;
  final String previewUrl;
  final VoidCallback onRemove;

  const _MediaThumb({
    required this.size,
    required this.isVideo,
    required this.previewUrl,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
          child: previewUrl.isEmpty
              ? const Icon(Icons.broken_image_outlined)
              : Image(
                  image: cachedImageProvider(previewUrl),
                  fit: BoxFit.cover,
                ),
        ),
        if (isVideo)
          const Positioned.fill(
            child: Center(
              child: Icon(
                CupertinoIcons.play_circle_fill,
                color: AppColors.onPrimary,
                size: 26,
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
}

class _MediaUploadingPlaceholder extends StatelessWidget {
  final double size;
  const _MediaUploadingPlaceholder({required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderRadiusMedium,
        color: AppColors.iosGray.withValues(alpha: 0.12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
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
