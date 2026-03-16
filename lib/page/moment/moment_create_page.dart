import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/public.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
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

  int _visibility = 1;
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
    } catch (_) {
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
      EasyLoading.showInfo('内容或媒体至少填写一项');
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
      allowUids: _visibility == 3
          ? _parseUidList(_allowUidsController.text)
          : const [],
      denyUids: _visibility == 4
          ? _parseUidList(_denyUidsController.text)
          : const [],
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (created == null) {
      EasyLoading.showError('发布失败');
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
                title: const Text('选择视频'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickVideo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('拍摄视频'),
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
            decoration: const InputDecoration(
              hintText: '写点什么...',
              border: OutlineInputBorder(),
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
                label: Text('添加媒体 (${_media.length}/9)'),
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
                final url = parseModelString(media['url']);
                return Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      color: Colors.black12,
                      child: url.isEmpty
                          ? const Icon(Icons.broken_image_outlined)
                          : Image.network(url, fit: BoxFit.cover),
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
            decoration: const InputDecoration(
              labelText: '可见性',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('公开')),
              DropdownMenuItem(value: 1, child: Text('仅好友')),
              DropdownMenuItem(value: 2, child: Text('仅自己')),
              DropdownMenuItem(value: 3, child: Text('部分可见')),
              DropdownMenuItem(value: 4, child: Text('不给谁看')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _visibility = value;
              });
            },
          ),
          if (_visibility == 3) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _allowUidsController,
              decoration: const InputDecoration(
                labelText: '允许可见 UID 列表（逗号分隔）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_visibility == 4) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _denyUidsController,
              decoration: const InputDecoration(
                labelText: '不给谁看 UID 列表（逗号分隔）',
                border: OutlineInputBorder(),
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
            title: const Text('允许评论'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
