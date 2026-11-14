import 'package:imboy/component/ui/resource_page_layout.dart';

import 'dart:async';

import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/cupertino_modal_surface.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/ui/app_back_scope.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';

import 'channel_edit_avatar.dart';

import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
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
  MediaPickerCapability get _picker =>
      CapabilityLocator.I.get<MediaPickerCapability>();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  ChannelModel? _channel;
  ChannelModel? _baseline;
  late final AuthSessionScope _session;
  late final AccountLocalTaskOwner _owner;
  int _loadGeneration = 0;
  int _avatarGeneration = 0;
  bool _avatarUploadFailed = false;
  bool _isPickingAvatar = false;
  bool _discardApproved = false;
  Object? _savingProgress;

  bool get _saveBlocked =>
      _isSaving || _isUploadingAvatar || _avatarUploadFailed;

  bool get _sessionCurrent =>
      authSessionReader.isCurrent(_session) &&
      AccountLocalTaskOwner.capture() == _owner;

  bool get _hasChanges {
    final initial = _baseline;
    return initial != null &&
        (!isChannelUpdateApplied(
              channel: initial,
              name: _nameController.text,
              description: _descriptionController.text,
              avatar: _avatarUrl,
              tags: _tags,
            ) ||
            _customIdController.text != (initial.customId ?? '') ||
            _avatarFile != null ||
            _tagController.text.isNotEmpty);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onAuthChanged() {
    if (!mounted || _sessionCurrent) return;
    final progress = _savingProgress;
    if (progress != null) unawaited(AppLoading.dismissOwnedProgress(progress));
    setState(() {});
  }

  bool _currentLoad(int request, String target) =>
      mounted &&
      _sessionCurrent &&
      request == _loadGeneration &&
      target == widget.channelId;
  int _visibility = 0;
  int _accessType = 0;
  String? _avatarUrl;
  File? _avatarFile;
  final List<String> _tags = [];
  static const int _maxTags = 8;

  @override
  void initState() {
    super.initState();
    _session = authSessionReader.current;
    _owner = AccountLocalTaskOwner.capture();
    authSessionReader.addListener(_onAuthChanged);
    _nameController = TextEditingController(text: widget.channel?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.channel?.description ?? '',
    );
    _customIdController = TextEditingController(
      text: widget.channel?.customId ?? '',
    );
    _visibility = widget.channel?.visibility ?? 0;
    _accessType = widget.channel?.accessType ?? 0;
    _avatarUrl = widget.channel?.avatar;
    _tags
      ..clear()
      ..addAll(widget.channel?.tags ?? const []);
    _channel = widget.channel;
    _baseline = _channel;
    for (final controller in [
      _nameController,
      _descriptionController,
      _customIdController,
      _tagController,
    ]) {
      controller.addListener(_onChanged);
    }
    _loadChannel(showLoading: _channel == null);
  }

  @override
  void didUpdateWidget(covariant ChannelEditPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId == widget.channelId) return;
    _avatarGeneration++;
    final progress = _savingProgress;
    if (progress != null) unawaited(AppLoading.dismissOwnedProgress(progress));
    _savingProgress = null;
    _isSaving = false;
    _isPickingAvatar = false;
    _isLoading = false;
    _discardApproved = false;
    _channel = widget.channel;
    _baseline = _channel;
    _visibility = _channel?.visibility ?? 0;
    _accessType = _channel?.accessType ?? 0;
    _avatarFile = null;
    _avatarUploadFailed = false;
    _isUploadingAvatar = false;
    _avatarUrl = _channel?.avatar;
    _nameController.text = _channel?.name ?? '';
    _descriptionController.text = _channel?.description ?? '';
    _customIdController.text = _channel?.customId ?? '';
    _tagController.clear();
    _tags
      ..clear()
      ..addAll(_channel?.tags ?? const []);
    _loadChannel(showLoading: _channel == null);
  }

  @override
  void dispose() {
    authSessionReader.removeListener(_onAuthChanged);
    final progress = _savingProgress;
    if (progress != null) unawaited(AppLoading.dismissOwnedProgress(progress));
    _nameController.dispose();
    _descriptionController.dispose();
    _customIdController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadChannel({bool showLoading = true}) async {
    final request = ++_loadGeneration;
    final target = widget.channelId;
    if (!_sessionCurrent) return;
    if (showLoading) setState(() => _isLoading = true);
    try {
      final api = ref.read(channelApiProvider);
      var channel = await api.getChannel(target);
      if (!_currentLoad(request, target)) return;
      channel ??= await api.getChannelByCustomId(target);
      if (!_currentLoad(request, target) || channel == null) return;
      final latest = channel;
      final preserveDraft = _hasChanges;
      setState(() {
        _channel = latest;
        if (preserveDraft) return;
        _baseline = latest;
        _nameController.text = latest.name;
        _descriptionController.text = latest.description ?? '';
        _customIdController.text = latest.customId ?? '';
        _visibility = latest.visibility;
        _accessType = latest.accessType;
        _avatarUrl = latest.avatar;
        _avatarFile = null;
        _tags
          ..clear()
          ..addAll(latest.tags ?? const []);
      });
    } catch (_) {
      // The existing cached form remains usable when a refresh fails.
    } finally {
      if (mounted && request == _loadGeneration && showLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 自定义 ID 是否可编辑：仅当频道当前没有 ID 时允许补设一次。
  /// 判据取服务端返回的 [_channel]，不取输入框内容 —— 否则用户清空输入框
  /// 就能骗过前端把已有 ID 改掉（后端仍会拒，但前端不该给出假希望）。
  bool get _isCustomIdEditable => (_channel?.customId ?? '').trim().isEmpty;

  /// 与后端 custom_id 语义对齐：允许留空（表示不设置），非空则限定字符集。
  String? _validateCustomId(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (v.length < 4) return t.channel.customIdHint;
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(v)) {
      return t.channel.customIdHint;
    }
    return null;
  }

  Future<void> _saveChanges() async {
    if (_isSaving ||
        _isUploadingAvatar ||
        _avatarUploadFailed ||
        !_sessionCurrent ||
        _channel?.isManaged != true ||
        !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    final target = widget.channelId;
    final generation = _loadGeneration;
    final progress = _savingProgress = AppLoading.beginProgress();
    unawaited(AppLoading.showOwned(progress, status: t.main.saving));

    try {
      final api = ref.read(channelApiProvider);
      final channelId = (_channel?.id != null && _channel!.id != '0')
          ? _channel!.id.toString()
          : widget.channelId;
      final targetName = _nameController.text.trim();
      final targetDescription = _descriptionController.text.trim();
      final targetAvatar = _avatarUrl?.trim();
      final targetTags = normalizeTags(_tags);
      // 自定义 ID 只在原值为空时可设置；已有值则连传都不传，避免误触发后端
      // 「设过即锁定」的拒绝分支。
      final typedCustomId = _customIdController.text.trim();
      final targetCustomId = (_isCustomIdEditable && typedCustomId.isNotEmpty)
          ? typedCustomId
          : null;
      final result = await api.updateChannel(
        channelId,
        name: targetName,
        description: targetDescription,
        avatar: targetAvatar,
        tags: targetTags,
        customId: targetCustomId,
      );

      if (mounted && _currentLoad(generation, target)) {
        if (result != null &&
            isChannelUpdateApplied(
              channel: result,
              name: targetName,
              description: targetDescription,
              avatar: targetAvatar,
              tags: targetTags,
            )) {
          _channel = result;
          _discardApproved = true;
          AppLoading.showSuccess(t.channel.updateSuccess);
          context.pop(result); // 返回最新频道对象，避免详情页继续使用旧数据
        } else {
          AppLoading.showError(t.channel.updateFailed);
        }
      }
    } catch (_) {
      if (_currentLoad(generation, target)) {
        AppLoading.showError(t.channel.updateFailed);
      }
    } finally {
      unawaited(AppLoading.dismissOwnedProgress(progress));
      if (identical(_savingProgress, progress)) _savingProgress = null;
      if (mounted && generation == _loadGeneration) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAvatar({bool useCamera = false}) async {
    Navigator.of(context).pop();
    if (_isPickingAvatar || _isSaving || !_sessionCurrent) return;
    setState(() => _isPickingAvatar = true);
    final target = widget.channelId;
    final generation = _loadGeneration;
    try {
      final media = useCamera
          ? await _picker.pickCamera(context)
          : await _picker.pickSingle(context, MediaType.image);
      if (!_currentLoad(generation, target) || media == null) return;
      final file = File(media.path);
      setState(() => _avatarFile = file);
      await _uploadAvatar(file);
    } catch (_) {
      if (mounted && _currentLoad(generation, target)) {
        AppLoading.showToast(context.t.common.uploadFailed);
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isPickingAvatar = false);
      }
    }
  }

  Future<void> _uploadAvatar(File file) async {
    if (_isSaving || _isUploadingAvatar || !_sessionCurrent) return;
    final attempt = ++_avatarGeneration;
    final generation = _loadGeneration;
    final target = widget.channelId;
    setState(() {
      _isUploadingAvatar = true;
      _avatarUploadFailed = false;
    });
    String? uploaded;
    try {
      uploaded = await ref.read(channelEditAvatarUploadProvider)(
        file,
        _channel?.id ?? '',
      );
    } catch (_) {
      uploaded = null;
    }
    if (!_currentLoad(generation, target) || attempt != _avatarGeneration) {
      return;
    }
    setState(() {
      _isUploadingAvatar = false;
      _avatarUploadFailed = uploaded == null || uploaded.isEmpty;
      if (!_avatarUploadFailed) _avatarUrl = uploaded;
    });
  }

  void _restoreAvatar() {
    _avatarGeneration++;
    setState(() {
      _avatarFile = null;
      _avatarUrl = _baseline?.avatar;
      _avatarUploadFailed = false;
      _isUploadingAvatar = false;
    });
  }

  Future<void> _confirmLeave(bool didPop) async {
    if (didPop || _isSaving) return;
    final route = ModalRoute.of(context);
    final leave = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(context.t.channel.editLeaveUnsaved),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.t.common.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.t.common.confirm),
          ),
        ],
      ),
    );
    if (leave != true || !mounted || route?.isCurrent != true) return;
    setState(() => _discardApproved = true);
    Navigator.of(context).pop();
  }

  void _showAvatarPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoModalSurface(
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
    if (_isSaving || !_sessionCurrent || tag.isEmpty) return;
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
    if (_isSaving || !_sessionCurrent) return;
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    if (_isLoading) {
      return Scaffold(
        // 加载态 AppBar 也要与主态一致地显式打开返回键：频道编辑页是 push
        // 进来的，加载期间（尤其慢网）不能把用户困在转圈页面上。
        appBar: GlassAppBar(
          title: t.channel.editChannel,
          automaticallyImplyLeading: true,
        ),
        body: ResourcePageLayout(
          child: const Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    if (_channel == null) {
      return Scaffold(
        appBar: GlassAppBar(
          title: t.channel.editChannel,
          automaticallyImplyLeading: true,
        ),
        body: ResourcePageLayout(
          child: NoDataView(
            icon: CupertinoIcons.exclamationmark_circle,
            text: t.common.loadError,
            onTop: _loadChannel,
          ),
        ),
      );
    }

    // 0016：管理权限前置校验（UI-only）。数据源用已持有的模型
    //（widget.channel 或加载结果），不新增请求；非管理角色不渲染任何
    // 表单字段（服务端合同不变，此处只是不展示）。
    if (!_sessionCurrent || _channel?.isManaged != true) {
      return Scaffold(
        appBar: GlassAppBar(
          title: t.channel.editChannel,
          automaticallyImplyLeading: true,
        ),
        body: ResourcePageLayout(
          child: NoDataView(
            icon: CupertinoIcons.lock_fill,
            text: t.common.noPermission,
          ),
        ),
      );
    }

    return AppBackScope<ChannelModel>(
      canPop:
          _discardApproved ||
          (!_hasChanges && !_isSaving && !_isUploadingAvatar),
      onPopInvokedWithResult: (didPop, _) => _confirmLeave(didPop),
      child: Scaffold(
        appBar: GlassAppBar(
          title: t.channel.editChannel,
          automaticallyImplyLeading: true,
          rightDMActions: [
            CupertinoButton(
              minimumSize: const Size.square(AppSizes.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _saveBlocked ? null : _saveChanges,
              child: _isSaving
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Text(
                      t.common.save,
                      style: context.textStyle(
                        FontSizeType.body,
                        fontWeight: !_saveBlocked
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: !_saveBlocked
                            ? AppColors.getIosBlue(Theme.of(context).brightness)
                            : AppColors.iosGray,
                      ),
                    ),
            ),
          ],
        ),
        body: ResourcePageLayout(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.allRegular,
              children: [
                // 频道名称
                Text(
                  t.account.avatar,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.verticalSmall,
                ChannelEditAvatar(
                  file: _avatarFile,
                  url: _avatarUrl,
                  uploading: _isUploadingAvatar,
                  failed: _avatarUploadFailed,
                  onPick: (_isSaving || _isUploadingAvatar || _isPickingAvatar)
                      ? null
                      : _showAvatarPicker,
                  onRetry: _isSaving || _avatarFile == null
                      ? null
                      : () => _uploadAvatar(_avatarFile!),
                  onRestore: _isSaving ? null : _restoreAvatar,
                ),
                AppSpacing.verticalRegular,

                // 频道名称
                TextFormField(
                  enableSuggestions: false,
                  autocorrect: false,
                  controller: _nameController,
                  readOnly: _isSaving,
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
                  readOnly: _isSaving,
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
                    helperText: _isCustomIdEditable
                        ? t.channel.customIdHelper
                        : '${t.channel.customIdHelper} · ${t.channel.typeCannotChange}',
                  ),
                  // 创建时留空的频道允许补设一次；已有值则永久锁定（后端同样校验）。
                  readOnly: _isSaving || !_isCustomIdEditable,
                  enabled: _isCustomIdEditable,
                  maxLength: 32,
                  validator: _validateCustomId,
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
                        readOnly: _isSaving,
                        decoration: InputDecoration(
                          hintText: t.groupTag.tagName,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: _addTag,
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : () => _addTag(),
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
                            onDeleted: _isSaving ? null : () => _removeTag(tag),
                          ),
                        )
                        .toList(),
                  ),
                ],
                AppSpacing.verticalRegular,

                // 频道属性（只读显示）
                Text(
                  t.channel.visibilityLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.verticalSmall,
                Container(
                  padding: AppSpacing.allMedium,
                  decoration: BoxDecoration(
                    color: AppColors.getIosSeparator(
                      Theme.of(context).brightness,
                    ).withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _visibility == 0
                            ? CupertinoIcons.globe
                            : CupertinoIcons.lock,
                        color: AppColors.iosGray,
                      ),
                      AppSpacing.horizontalSmall,
                      Text(
                        _visibility == 0
                            ? t.channel.typePublic
                            : t.channel.typePrivate,
                        style: const TextStyle(color: AppColors.iosGray),
                      ),
                      if (_accessType == 1) ...[
                        AppSpacing.horizontalSmall,
                        Icon(
                          CupertinoIcons.money_dollar,
                          color: AppColors.iosOrange,
                          size: 16,
                        ),
                        AppSpacing.horizontalTiny,
                        Text(
                          t.channel.accessTypePaid,
                          style: const TextStyle(color: AppColors.iosOrange),
                        ),
                      ],
                    ],
                  ),
                ),
                AppSpacing.verticalXLarge,

                // 统计信息
                if (_channel != null) ...[
                  Text(
                    t.channel.stats,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  AppSpacing.verticalSmall,
                  Container(
                    padding: AppSpacing.allMedium,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Column(
                      children: [
                        _buildStatRow(
                          CupertinoIcons.person_2,
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
          AppSpacing.horizontalSmall,
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
