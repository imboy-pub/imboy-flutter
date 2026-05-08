import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/application/moment_facade.dart';
import 'package:imboy/page/moment/moment_friend_picker/moment_friend_picker_page.dart';
import 'package:imboy/page/moment/moment_interactions.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

class MomentCreatePage extends StatefulWidget {
  const MomentCreatePage({super.key});

  @override
  State<MomentCreatePage> createState() => _MomentCreatePageState();
}

class _MomentCreatePageState extends State<MomentCreatePage> {
  final MomentFacade _api = MomentFacade.instance;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _allowUidsController = TextEditingController();
  final TextEditingController _denyUidsController = TextEditingController();

  final List<Map<String, dynamic>> _media = [];

  int _visibility = momentVisibilityFriends;
  bool _allowComment = true;
  bool _isUploading = false;
  bool _isSubmitting = false;

  /// 失败草稿 storage key。逻辑抽在 [momentFailedDraftKey]（可单测）。
  String get _draftKey => momentFailedDraftKey(UserRepoLocal.to.currentUid);

  @override
  void initState() {
    super.initState();
    // 首帧后尝试恢复上次发布失败残留的草稿
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
      // 注：media 不做自动恢复 —— 仅保留 URL 无法还原 type/cover，
      // 强行填充会让发布时校验误判。让用户重选即可。
    });
    EasyLoading.showInfo(context.t.momentsDraftRestored);
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

  Future<String?> _uploadFile(String prefix, File file) async {
    final completer = Completer<String?>();
    await AttachmentApi.uploadFile(
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

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploading || _media.length >= momentMaxImageCount) return;
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    setState(() {
      _isUploading = true;
    });
    final url = await _uploadFile('img', File(file.path));
    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (url != null && url.isNotEmpty) {
        _media.add(<String, dynamic>{'type': 'image', 'url': url});
      }
    });
    if (url == null || url.isEmpty) {
      EasyLoading.showError(context.t.momentsUploadFailed);
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_isUploading || _media.length >= momentMaxImageCount) return;
    final video = await _picker.pickVideo(source: source);
    if (video == null || !mounted) return;

    setState(() {
      _isUploading = true;
    });
    final file = File(video.path);
    final url = await _uploadFile('video', file);

    String coverUrl = '';
    int durationMs = 0;
    try {
      final thumb = await VideoCompress.getFileThumbnail(
        video.path,
        quality: 60,
        position: -1,
      );
      final uploadedCover = await _uploadFile('img', thumb);
      coverUrl = uploadedCover ?? '';
      final mediaInfo = await VideoCompress.getMediaInfo(video.path);
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
      EasyLoading.showError(context.t.momentsUploadFailed);
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
      EasyLoading.showInfo(context.t.momentsContentOrMediaRequired);
      return;
    }

    // 发布前媒体校验：9 图上限 / 1 视频上限 / 图视频互斥。
    // 即使 _pickImage/_pickVideo 已做前置限制，这里仍再校一次防御
    // 旧载荷 / 手改 state 绕过。
    final validation = validateMediaSelection(_media);
    if (!validation.ok) {
      final t = context.t;
      final msg = switch (validation.error) {
        momentMediaErrorTooManyImages => t.momentsMediaTooManyImages,
        momentMediaErrorTooManyVideos => t.momentsMediaTooManyVideos,
        momentMediaErrorMixed => t.momentsMediaMixedImageAndVideo,
        _ => t.momentsPublishFailed,
      };
      EasyLoading.showInfo(msg);
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
      // 发布失败 —— 持久化草稿避免用户白打字
      await _saveFailedDraft(content);
      if (!mounted) return;
      EasyLoading.showError(context.t.momentsPublishFailed);
      return;
    }

    // 发布成功，清除残留草稿
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

  /// 弹出好友选择器并把结果写回指定 controller。
  /// 结果为 null 视为取消，不清空已有值。
  Future<void> _pickUids({
    required TextEditingController controller,
    required String title,
  }) async {
    final initial = parseMomentUidList(controller.text);
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (_) =>
            MomentFriendPickerPage(title: title, initialSelectedUids: initial),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      controller.text = result.join(',');
    });
  }

  Widget _buildUidPickerField({
    required TextEditingController controller,
    required String labelText,
    required String placeholder,
    required String pickerTitle,
  }) {
    final selectedCount = parseMomentUidList(controller.text).length;
    return InkWell(
      onTap: () => _pickUids(controller: controller, title: pickerTitle),
      borderRadius: AppRadius.borderRadiusTiny,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.chevron_right),
        ),
        child: Text(
          selectedCount == 0
              ? placeholder
              : context.t.momentFriendPicker.selectedCount(
                  count: selectedCount,
                ),
          style: selectedCount == 0
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.t.selectFromAlbum),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(context.t.takePhoto),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: Text(context.t.momentsSelectVideo),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickVideo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text(context.t.momentsRecordVideo),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickVideo(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.momentsSend),
        actions: [
          TextButton(
            onPressed: _isSubmitting || _isUploading ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.confirm),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _contentController,
            maxLines: 6,
            maxLength: 5000,
            decoration: InputDecoration(
              hintText: t.momentsContentHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed:
                    (_isUploading || _media.length >= momentMaxImageCount)
                    ? null
                    : _showPicker,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  '${t.momentsAddMedia} (${_media.length}/$momentMaxImageCount)',
                ),
              ),
              if (_isUploading) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          if (_media.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_media.length, (index) {
                final media = _media[index];
                final type = parseModelString(media['type']);
                final previewUrl = pickMediaPreviewUrl(media);
                return Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      color: Colors.black12,
                      child: previewUrl.isEmpty
                          ? const Icon(Icons.broken_image_outlined)
                          : Image(
                              image: cachedImageProvider(previewUrl),
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (type == 'video')
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: InkWell(
                        onTap: () => _removeMedia(index),
                        child: Container(
                          color: Colors.black45,
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            key: ValueKey<int>(_visibility),
            initialValue: _visibility,
            decoration: InputDecoration(
              labelText: context.t.momentsVisibility,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: momentVisibilityPublic,
                child: Text(context.t.momentsVisibilityPublic),
              ),
              DropdownMenuItem(
                value: momentVisibilityFriends,
                child: Text(context.t.momentsVisibilityFriends),
              ),
              DropdownMenuItem(
                value: momentVisibilityPrivate,
                child: Text(context.t.momentsVisibilityPrivate),
              ),
              DropdownMenuItem(
                value: momentVisibilityAllowList,
                child: Text(context.t.momentsVisibilityPartial),
              ),
              DropdownMenuItem(
                value: momentVisibilityDenyList,
                child: Text(context.t.momentsVisibilityExclude),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _visibility = value;
              });
            },
          ),
          if (momentVisibilityRequiresAllowUids(_visibility)) ...[
            const SizedBox(height: 12),
            _buildUidPickerField(
              controller: _allowUidsController,
              labelText: t.momentsAllowUidsLabel,
              placeholder: t.momentFriendPicker.titleAllow,
              pickerTitle: t.momentFriendPicker.titleAllow,
            ),
          ],
          if (momentVisibilityRequiresDenyUids(_visibility)) ...[
            const SizedBox(height: 12),
            _buildUidPickerField(
              controller: _denyUidsController,
              labelText: t.momentsDenyUidsLabel,
              placeholder: t.momentFriendPicker.titleDeny,
              pickerTitle: t.momentFriendPicker.titleDeny,
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            value: _allowComment,
            onChanged: (value) {
              setState(() {
                _allowComment = value;
              });
            },
            title: Text(context.t.momentsAllowComment),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
