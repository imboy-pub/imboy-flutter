import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:image_picker/image_picker.dart';

import 'channel_provider.dart';

/// 创建频道页面
class ChannelCreatePage extends ConsumerStatefulWidget {
  const ChannelCreatePage({super.key});

  @override
  ConsumerState<ChannelCreatePage> createState() => _ChannelCreatePageState();
}

class _ChannelCreatePageState extends ConsumerState<ChannelCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customIdController = TextEditingController();
  final _tagController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  int _selectedType = 0;
  bool _isPublic = true;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  File? _avatarFile;
  final List<String> _tags = [];
  static const int _maxTags = 8;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customIdController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingAvatar) return;

    final notifier = ref.read(createChannelProvider.notifier);

    final channel = await notifier.createChannel(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      customId: _customIdController.text.trim().isNotEmpty
          ? _customIdController.text.trim()
          : null,
      type: _selectedType,
      avatar: _avatarUrl,
      tags: _tags.isEmpty ? null : _tags,
    );

    if (channel != null && mounted) {
      // 刷新频道列表
      unawaited(
        ref.read(channelListProvider.notifier).loadSubscribedChannels(),
      );
      // 跳转到频道详情
      context.pushReplacement('/channel/${channel.id}');
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final file = File(image.path);
      setState(() => _avatarFile = file);
      await _uploadAvatar(file);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.common.uploadFailed)));
    }
  }

  Future<void> _uploadAvatar(File file) async {
    if (_isUploadingAvatar) return;
    setState(() => _isUploadingAvatar = true);

    String? uploadedUrl;
    final completer = Completer<bool>();

    await AttachmentApi.uploadFile(
      'avatar',
      file,
      (Map<String, dynamic> resp, String url) {
        if (!completer.isCompleted) {
          final status = resp['status']?.toString() ?? '';
          if (status == 'ok') {
            uploadedUrl = url;
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        }
      },
      (_) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      process: true,
    );

    final success = await completer.future;
    if (!mounted) return;

    setState(() {
      _isUploadingAvatar = false;
      _avatarUrl = success ? uploadedUrl : null;
    });

    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.common.uploadFailed)));
    }
  }

  void _showAvatarPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(context.t.main.takePhoto),
              onTap: () => _pickAvatar(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.t.main.selectFromAlbum),
              onTap: () => _pickAvatar(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(context.t.common.buttonCancel),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _addTag([String? input]) {
    final tag = (input ?? _tagController.text).trim();
    if (tag.isEmpty) return;
    if (_tags.contains(tag)) {
      _tagController.clear();
      return;
    }
    if (_tags.length >= _maxTags) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.contact.channelMaxTagsCount)));
      return;
    }
    setState(() => _tags.add(tag));
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(createChannelProvider);

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.create,
        automaticallyImplyLeading: true,
        rightDMActions: [
          TextButton(
            onPressed: (state.isCreating || _isUploadingAvatar)
                ? null
                : _createChannel,
            child: state.isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.common.confirm),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t.account.avatar,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Center(
              child: InkWell(
                onTap: _isUploadingAvatar ? null : _showAvatarPicker,
                borderRadius: BorderRadius.circular(48),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : null,
                      child: _avatarFile == null
                          ? const Icon(Icons.camera_alt_outlined, size: 30)
                          : null,
                    ),
                    if (_isUploadingAvatar)
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(44),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 频道名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t.channel.nameLabel,
                hintText: t.channel.nameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.campaign),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.channel.nameRequired;
                }
                if (value.trim().length > 50) {
                  return t.channel.nameTooLong;
                }
                return null;
              },
              maxLength: 50,
            ),
            const SizedBox(height: 16),

            // 频道描述
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: t.channel.descriptionLabel,
                hintText: t.channel.descriptionHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // 自定义 ID
            TextFormField(
              controller: _customIdController,
              decoration: InputDecoration(
                labelText: t.channel.customIdLabel,
                hintText: t.channel.customIdHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.alternate_email),
                helperText: t.channel.customIdHelper,
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return t.channel.customIdInvalid;
                  }
                  if (value.length < 4 || value.length > 30) {
                    return t.channel.customIdLength;
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 标签
            Text(
              t.groupTag.addTag,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: t.groupTag.tagName,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                IconButton(
                  onPressed: () => _addTag(),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: t.groupTag.addTag,
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags
                    .map(
                      (tag) => InputChip(
                        label: Text(tag),
                        onDeleted: () => _removeTag(tag),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),

            // 频道类型
            Text(
              t.channel.typeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(t.channel.typePublic),
                  icon: const Icon(Icons.public),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(t.channel.typePrivate),
                  icon: const Icon(Icons.lock_outline),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<int> selection) {
                setState(() {
                  _selectedType = selection.first;
                  _isPublic = _selectedType == 0;
                });
              },
            ),
            const SizedBox(height: 24),

            // 频道类型说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusSmall,
              ),
              child: Row(
                children: [
                  Icon(
                    _isPublic ? Icons.public : Icons.lock_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isPublic
                          ? t.channel.typePublicDesc
                          : t.channel.typePrivateDesc,
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 提示信息
            Text(
              t.channel.createTips,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),

            // 错误信息
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.iosRed.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.iosRed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.iosRed),
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
