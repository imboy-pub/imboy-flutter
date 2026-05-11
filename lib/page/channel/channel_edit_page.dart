import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/page/channel/channel_edit_rules.dart';

/// 编辑频道页面
class ChannelEditPage extends ConsumerStatefulWidget {
  final String channelId;
  final ChannelModel? channel;

  const ChannelEditPage({super.key, required this.channelId, this.channel});

  @override
  ConsumerState<ChannelEditPage> createState() => _ChannelEditPageState();
}

class _ChannelEditPageState extends ConsumerState<ChannelEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _customIdController;
  final _tagController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  ChannelModel? _channel;
  int _selectedType = 0;
  String? _avatarUrl;
  File? _avatarFile;
  final List<String> _tags = [];
  static const int _maxTags = 8;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.channel?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.channel?.description ?? '',
    );
    _customIdController = TextEditingController(
      text: widget.channel?.customId ?? '',
    );
    _selectedType = widget.channel?.type.index ?? 0;
    _avatarUrl = widget.channel?.avatar;
    _tags
      ..clear()
      ..addAll(widget.channel?.tags ?? const []);
    _channel = widget.channel;
    _loadChannel(showLoading: _channel == null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customIdController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadChannel({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final api = ChannelApi();
      ChannelModel? channel = await api.getChannel(widget.channelId);
      channel ??= await api.getChannelByCustomId(widget.channelId);
      if (mounted && channel != null) {
        final latest = channel;
        setState(() {
          _channel = latest;
          _nameController.text = latest.name;
          _descriptionController.text = latest.description ?? '';
          _customIdController.text = latest.customId ?? '';
          _selectedType = latest.type.index;
          _avatarUrl = latest.avatar;
          _avatarFile = null;
          _tags
            ..clear()
            ..addAll(latest.tags ?? const []);
        });
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final api = ChannelApi();
      final channelId = (_channel?.id != null && _channel!.id != 0)
          ? _channel!.id.toString()
          : widget.channelId;
      final targetName = _nameController.text.trim();
      final targetDescription = _descriptionController.text.trim();
      final targetAvatar = _avatarUrl?.trim();
      final targetTags = normalizeTags(_tags);
      final result = await api.updateChannel(
        channelId,
        name: targetName,
        description: targetDescription,
        avatar: targetAvatar,
        tags: targetTags,
      );

      if (mounted) {
        if (result != null &&
            isChannelUpdateApplied(
              channel: result,
              name: targetName,
              description: targetDescription,
              avatar: targetAvatar,
              tags: targetTags,
            )) {
          _channel = result;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.updateSuccess)));
          context.pop(result); // 返回最新频道对象，避免详情页继续使用旧数据
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.channel.updateFailed),
              backgroundColor: AppColors.iosRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.channel.updateFailed),
            backgroundColor: AppColors.iosRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
      ).showSnackBar(SnackBar(content: Text(context.t.uploadFailed)));
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
        if (completer.isCompleted) return;
        final status = resp['status']?.toString() ?? '';
        if (status == 'ok') {
          uploadedUrl = url;
          completer.complete(true);
        } else {
          completer.complete(false);
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
      _avatarUrl = success ? uploadedUrl : _avatarUrl;
    });

    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.uploadFailed)));
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
              title: Text(context.t.takePhoto),
              onTap: () => _pickAvatar(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.t.selectFromAlbum),
              onTap: () => _pickAvatar(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(context.t.buttonCancel),
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
      ).showSnackBar(SnackBar(content: Text(t.channelMaxTagsCount)));
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

    if (_isLoading) {
      return Scaffold(
        appBar: GlassAppBar(title: t.channel.editChannel),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.editChannel,
        automaticallyImplyLeading: true,
        rightDMActions: [
          TextButton(
            onPressed: (_isSaving || _isUploadingAvatar) ? null : _saveChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 频道名称
            Text(t.avatar, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Center(
              child: InkWell(
                onTap: (_isSaving || _isUploadingAvatar)
                    ? null
                    : _showAvatarPicker,
                borderRadius: BorderRadius.circular(48),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                          ? cachedImageProvider(_avatarUrl!, w: 176)
                          : null,
                      child:
                          (_avatarFile == null &&
                              (_avatarUrl == null || _avatarUrl!.isEmpty))
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
                helperText:
                    '${t.channel.customIdHelper} · ${t.channel.typeCannotChange}',
              ),
              readOnly: true,
              enabled: false,
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

            // 频道类型（只读显示）
            Text(
              t.channel.typeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusSmall,
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedType == 0 ? Icons.public : Icons.lock_outline,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedType == 0
                        ? t.channel.typePublic
                        : t.channel.typePrivate,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    t.channel.typeCannotChange,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 统计信息
            if (_channel != null) ...[
              Text(
                t.channel.stats,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                      Icons.people_outline,
                      t.channel.subscribers,
                      _channel!.subscriberCount.toString(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
