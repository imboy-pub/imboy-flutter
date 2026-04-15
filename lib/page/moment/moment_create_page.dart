import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/application/moment_facade.dart';
import 'package:imboy/page/moment/moment_interactions.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
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

  @override
  void dispose() {
    _contentController.dispose();
    _allowUidsController.dispose();
    _denyUidsController.dispose();
    super.dispose();
  }

  List<String> _parseUidList(String raw) {
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
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
    if (_isUploading || _media.length >= 9) return;
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
    if (_isUploading || _media.length >= 9) return;
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

    setState(() {
      _isSubmitting = true;
    });
    final created = await _api.createPost(
      content: content,
      media: _media,
      visibility: _visibility,
      allowComment: _allowComment,
      allowUids: momentVisibilityRequiresAllowUids(_visibility)
          ? _parseUidList(_allowUidsController.text)
          : const [],
      denyUids: momentVisibilityRequiresDenyUids(_visibility)
          ? _parseUidList(_denyUidsController.text)
          : const [],
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (created == null) {
      EasyLoading.showError(context.t.momentsPublishFailed);
      return;
    }

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
                onPressed: (_isUploading || _media.length >= 9)
                    ? null
                    : _showPicker,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('${t.momentsAddMedia} (${_media.length}/9)'),
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
            TextField(
              controller: _allowUidsController,
              decoration: InputDecoration(
                labelText: t.momentsAllowUidsLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (momentVisibilityRequiresDenyUids(_visibility)) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _denyUidsController,
              decoration: InputDecoration(
                labelText: t.momentsDenyUidsLabel,
                border: const OutlineInputBorder(),
              ),
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
