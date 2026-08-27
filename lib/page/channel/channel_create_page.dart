import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';

import 'channel_provider.dart';
import 'package:imboy/component/ui/app_loading.dart';

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
  final _scrollController = ScrollController();
  MediaPickerCapability get _picker =>
      CapabilityLocator.I.get<MediaPickerCapability>();
  int _visibility = 0; // 0=public, 1=private
  int _accessType = 0; // 0=free, 1=paid
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  File? _avatarFile;
  final List<String> _tags = [];
  static const int _maxTags = 8;

  /// 根据 visibility + accessType 计算 join_policy
  int get _joinPolicy {
    if (_accessType == 1) return 3; // paid → purchase
    if (_visibility == 1) return 1; // private + free → invite
    return 0; // public + free → open
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customIdController.dispose();
    _tagController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingAvatar) return;

    FocusScope.of(context).unfocus();

    final notifier = ref.read(createChannelProvider.notifier);

    final channel = await notifier.createChannel(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      customId: _customIdController.text.trim().isNotEmpty
          ? _customIdController.text.trim()
          : null,
      visibility: _visibility,
      accessType: _accessType,
      joinPolicy: _joinPolicy,
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

  Future<void> _pickAvatar({bool useCamera = false}) async {
    Navigator.of(context).pop();
    try {
      // 「拍照」此前和「从相册选择」调的是同一个 pickSingle(gallery)，从未
      // 真正唤起相机；useCamera 时走 pickCamera（与头像编辑页同款修复）。
      final media = useCamera
          ? await _picker.pickCamera(context)
          : await _picker.pickSingle(context, MediaType.image);
      if (media == null || !mounted) return;

      final file = File(media.path);
      setState(() => _avatarFile = file);
      await _uploadAvatar(file);
    } catch (e) {
      iPrint('[ChannelCreate] 上传头像失败: $e');
      if (!mounted) return;
      AppLoading.showToast(context.t.common.uploadFailed);
    }
  }

  Future<void> _uploadAvatar(File file) async {
    if (_isUploadingAvatar) return;
    setState(() => _isUploadingAvatar = true);

    String? uploadedUrl;
    final completer = Completer<bool>();

    await AttachmentApi.uploadFileViaPresignCompat(
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
      AppLoading.showToast(context.t.common.uploadFailed);
    }
  }

  void _showAvatarPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.camera),
              title: Text(context.t.main.takePhoto),
              onTap: () => _pickAvatar(useCamera: true),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.photo_on_rectangle),
              title: Text(context.t.main.selectFromAlbum),
              onTap: () => _pickAvatar(),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.xmark),
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
      AppLoading.showToast(t.contact.channelMaxTagsCount);
      return;
    }
    setState(() => _tags.add(tag));
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  /// 根据可见性和付费属性生成频道类型描述
  String _buildChannelTypeDesc(Translations t) {
    if (_accessType == 1) {
      return _visibility == 0
          ? t.channel.typePublicPaidDesc
          : t.channel.typePrivatePaidDesc;
    }
    return _visibility == 0
        ? t.channel.typePublicDesc
        : t.channel.typePrivateDesc;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(createChannelProvider);

    ref.listen<CreateChannelState>(createChannelProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        // Dismiss keyboard first
        FocusScope.of(context).unfocus();

        // Show Snackbar
        AppLoading.showToast(next.error!);

        // Scroll to the bottom to make sure the error container at the bottom is visible
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.create,
        automaticallyImplyLeading: true,
        rightDMActions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: (state.isCreating || _isUploadingAvatar)
                ? null
                : _createChannel,
            child: state.isCreating
                ? const CupertinoActivityIndicator(radius: 10)
                : Text(
                    t.common.confirm,
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: !(state.isCreating || _isUploadingAvatar)
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: !(state.isCreating || _isUploadingAvatar)
                          ? AppColors.getIosBlue(Theme.of(context).brightness)
                          : AppColors.iosGray,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: AppSpacing.allRegular,
          children: [
            Text(
              t.account.avatar,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.verticalSmall,
            Center(
              child: GestureDetector(
                onTap: _isUploadingAvatar ? null : _showAvatarPicker,
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
                          ? const Icon(CupertinoIcons.camera, size: 30)
                          : null,
                    ),
                    if (_isUploadingAvatar)
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.darkBackground.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(44),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CupertinoActivityIndicator(),
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
                          CupertinoIcons.pencil,
                          size: 16,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.verticalRegular,

            // 频道名称
            TextFormField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t.channel.nameLabel,
                hintText: t.channel.nameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(CupertinoIcons.speaker_2),
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
            AppSpacing.verticalRegular,

            // 频道描述
            TextFormField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: t.channel.descriptionLabel,
                hintText: t.channel.descriptionHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(CupertinoIcons.doc_text),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            AppSpacing.verticalRegular,

            // 自定义 ID
            TextFormField(
              enableSuggestions: false,
              autocorrect: false,
              controller: _customIdController,
              decoration: InputDecoration(
                labelText: t.channel.customIdLabel,
                hintText: t.channel.customIdHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(CupertinoIcons.at),
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
            AppSpacing.verticalRegular,

            // 标签
            Text(
              t.groupTag.addTag,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.verticalSmall,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    enableSuggestions: false,
                    autocorrect: false,
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
                  icon: const Icon(CupertinoIcons.add_circled),
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
            AppSpacing.verticalRegular,

            // 频道可见性
            Text(
              t.channel.visibilityLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.verticalSmall,
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(t.channel.typePublic),
                  icon: const Icon(CupertinoIcons.globe),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(t.channel.typePrivate),
                  icon: const Icon(CupertinoIcons.lock),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (Set<int> selection) {
                setState(() => _visibility = selection.first);
              },
            ),
            AppSpacing.verticalRegular,

            // 付费属性
            Text(
              t.channel.accessTypeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.verticalSmall,
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(t.channel.accessTypeFree),
                  icon: const Icon(CupertinoIcons.gift),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(t.channel.accessTypePaid),
                  icon: const Icon(CupertinoIcons.money_dollar),
                ),
              ],
              selected: {_accessType},
              onSelectionChanged: (Set<int> selection) {
                setState(() => _accessType = selection.first);
              },
            ),
            AppSpacing.verticalXLarge,

            // 组合说明
            Container(
              padding: AppSpacing.allMedium,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusSmall,
              ),
              child: Row(
                children: [
                  Icon(
                    _visibility == 0
                        ? CupertinoIcons.globe
                        : CupertinoIcons.lock,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  AppSpacing.horizontalSmall,
                  Expanded(
                    child: Text(
                      _buildChannelTypeDesc(t),
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.verticalXLarge,

            // 提示信息
            Text(
              t.channel.createTips,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.getTextColor(
                  Theme.of(context).brightness,
                  isSecondary: true,
                ),
              ),
            ),

            // 错误信息
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: AppSpacing.allMedium,
                decoration: BoxDecoration(
                  color: AppColors.iosRed.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      color: AppColors.iosRed,
                      size: 20,
                    ),
                    AppSpacing.horizontalSmall,
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
