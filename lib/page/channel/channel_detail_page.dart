import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/payment_launcher.dart';
import 'package:imboy/store/api/wallet_api.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/voice_record/voice_widget.dart';
import 'package:xid/xid.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'channel_detail_rules.dart';
import 'channel_message_item.dart';
import 'channel_payment_method_sheet.dart';
import 'channel_provider.dart';
import 'channel_purchase_provider.dart';

/// 频道详情页面
///
/// 显示频道消息列表，根据用户角色显示不同的 UI：
/// - 订阅者：查看消息、点赞/反应、取消订阅
/// - 管理员/创建者：发布消息、管理频道、置顶/删除消息
class ChannelDetailPage extends ConsumerStatefulWidget {
  final String channelId;
  final bool autoLoadStats;

  const ChannelDetailPage({
    super.key,
    required this.channelId,
    this.autoLoadStats = true,
  });

  @override
  ConsumerState<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends ConsumerState<ChannelDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  ChannelStatsModel? _stats;
  late final ChannelService _channelService = ref.read(channelServiceProvider);
  bool _isUploadingMedia = false;
  bool _showVoiceInput = false;
  bool _isPaying = false;
  bool _isLoadingStats = false;
  String? _statsRequestedChannelId;
  // P1 修复：监听消息首次加载，自动清零未读徽标
  ProviderSubscription<ChannelDetailState>? _markReadSub;

  @override
  void initState() {
    super.initState();

    // 加载频道详情
    Future.microtask(() {
      ref.read(channelDetailProvider.notifier).loadChannel(widget.channelId);
    });

    _scrollController.addListener(_onScroll);

    // P1 修复：消息首次加载完毕后自动 markAsRead，清零未读徽标
    _markReadSub = ref.listenManual<ChannelDetailState>(channelDetailProvider, (
      prev,
      next,
    ) {
      final wasEmpty = prev?.messages.isEmpty ?? true;
      if (wasEmpty && next.messages.isNotEmpty) {
        final latestId = next.messages.first.id.toString();
        ref.read(channelDetailProvider.notifier).markAsRead(latestId);
        // 一次性：完成后取消订阅
        _markReadSub?.close();
        _markReadSub = null;
      }
    });
  }

  String _resolveChannelId([ChannelModel? channel]) {
    final id = channel?.id;
    if (id != null && id != 0) return id.toString();
    return widget.channelId;
  }

  Future<void> _loadStats([String? channelId]) async {
    if (_isLoadingStats) return;
    final id = (channelId != null && channelId.isNotEmpty)
        ? channelId
        : widget.channelId;
    _isLoadingStats = true;
    try {
      final stats = await _channelService.getChannelStats(id);
      if (mounted && stats != null) {
        setState(() {
          _stats = stats;
        });
      }
    } finally {
      _isLoadingStats = false;
    }
  }

  @override
  void dispose() {
    _markReadSub?.close();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(channelDetailProvider.notifier).loadMoreMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(channelDetailProvider);
    final channel = state.channel;
    if (widget.autoLoadStats &&
        channel != null &&
        (_stats == null || _stats!.channelId != channel.id) &&
        _statsRequestedChannelId != channel.id.toString()) {
      _statsRequestedChannelId = channel.id.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadStats(channel.id.toString());
      });
    }

    return Scaffold(
      appBar: GlassAppBar(
        title: channel?.name ?? t.channel.loading,
        automaticallyImplyLeading: true,
        rightDMActions: _buildAppBarActions(channel),
      ),
      body: _buildBody(state),
      // 管理员/创建者显示消息输入框
      bottomNavigationBar: channel?.canPublish == true
          ? _buildMessageInput(
              channel!,
              state.isPublishing || _isUploadingMedia,
            )
          : null,
    );
  }

  /// 构建AppBar操作按钮
  List<Widget> _buildAppBarActions(ChannelModel? channel) {
    if (channel == null) return [];

    final isManaged = channel.isManaged;

    return [
      if (channel.canPublish)
        IconButton(
          icon: const Icon(Icons.campaign_outlined),
          onPressed: _focusPublishInput,
          tooltip: context.t.main.publish,
        ),
      // 管理员显示设置按钮
      if (isManaged)
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            _showChannelSettings(channel);
          },
          tooltip: context.t.channel.settings,
        ),
      // 更多菜单
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) => _handleMenuAction(value, channel),
        itemBuilder: (context) => _buildMenuItems(channel),
      ),
    ];
  }

  /// 构建菜单项

  List<PopupMenuEntry<String>> _buildMenuItems(ChannelModel channel) {
    final t = context.t;
    final isManaged = channel.isManaged;
    final isSubscribed = channel.isSubscribed;
    final canPublish = channel.canPublish;
    final invitationEnabled = AppFeatureRegistry.isEnabled(
      FeatureKeys.channelInvitation,
    );
    final orderEnabled = AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder);
    final items = <PopupMenuEntry<String>>[];

    if (canPublish) {
      items.add(
        PopupMenuItem(
          value: 'publish',
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(t.main.publish),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    if (isManaged) {
      items.addAll([
        PopupMenuItem(
          value: 'edit_channel',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(t.channel.editChannel),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'manage_admins',
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(t.channel.manageAdmins),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'manage_subscribers',
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(t.channel.manageSubscribers),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ]);
    } else if (isSubscribed) {
      items.add(
        PopupMenuItem(
          value: 'unsubscribe',
          child: ListTile(
            leading: const Icon(Icons.unsubscribe_outlined),
            title: Text(t.channel.unsubscribe),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    if (invitationEnabled) {
      items.add(
        PopupMenuItem(
          value: 'invitation_center',
          child: ListTile(
            leading: const Icon(Icons.mark_email_unread_outlined),
            title: Text(t.common.channelInvitations),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }
    items.add(
      PopupMenuItem(
        value: 'share',
        child: ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(t.channel.share),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
    if (channel.type == ChannelType.paid && orderEnabled) {
      items.add(
        PopupMenuItem(
          value: 'my_orders',
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(t.main.myOrders),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    return items;
  }

  void _focusPublishInput() {
    if (!_messageFocusNode.canRequestFocus) return;
    _messageFocusNode.requestFocus();
  }

  /// 构建消息输入框
  Widget _buildMessageInput(ChannelModel channel, bool isBusy) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceGrouped = isDark
        ? AppColors.darkBackground
        : AppColors.lightSurfaceGrouped;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final separator = isDark
        ? AppColors.iosTertiaryLabel
        : AppColors.iosSeparator;

    final bool hasText = _messageController.text.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: surfaceGrouped,
        border: Border(top: BorderSide(color: separator, width: 0.33)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 左侧 + 按钮
          IconButton(
            icon: const Icon(Icons.add, size: 28),
            color: AppColors.getTextColor(
              Theme.of(context).brightness,
              isSecondary: true,
            ),
            onPressed: isBusy ? null : () => _pickAndSendMedia(channel),
          ),
          // 语音/键盘 切换按钮
          IconButton(
            icon: Icon(
              _showVoiceInput ? Icons.keyboard_alt_outlined : Icons.mic_none,
              size: 28,
            ),
            color: AppColors.getTextColor(
              Theme.of(context).brightness,
              isSecondary: true,
            ),
            onPressed: isBusy
                ? null
                : () {
                    setState(() {
                      _showVoiceInput = !_showVoiceInput;
                      if (_showVoiceInput) {
                        _messageFocusNode.unfocus();
                      } else {
                        _messageFocusNode.requestFocus();
                      }
                    });
                  },
          ),
          // 输入框
          Expanded(
            child: _showVoiceInput
                ? VoiceWidget(
                    startRecord: () {},
                    stopRecord: _handleVoiceRecordFinished,
                    height: 44,
                    margin: EdgeInsets.zero,
                  )
                : Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      maxHeight: 120,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: AppRadius.borderRadiusRegular,
                      border: Border.all(
                        color: isDark
                            ? AppColors.iosSeparatorDark
                            : AppColors.iosSeparator.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      enabled: !isBusy,
                      onChanged: (_) {
                        // 触发 UI 刷新以切换发送按钮
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: context.t.channel.writeMessage,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10, // 调整以垂直居中
                        ),
                      ),
                      style: context
                          .textStyle(
                            FontSizeType.body,
                            color: AppColors.getTextColor(
                              Theme.of(context).brightness,
                            ),
                          )
                          .copyWith(height: 1.4), // CJK行高

                      maxLines: null, // 允许自动折行
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!isBusy) {
                          _sendMessage(channel);
                        }
                      },
                    ),
                  ),
          ),
          if (!_showVoiceInput) ...[
            AppSpacing.horizontalSmall,
            // 右侧：发送按钮
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasText ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: isBusy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : hasText
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: AppColors.onPrimary,
                      ),
                      onPressed: () => _sendMessage(channel),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  /// 发送消息
  Future<void> _sendMessage(ChannelModel channel) async {
    if (ref.read(channelDetailProvider).isPublishing || _isUploadingMedia) {
      return;
    }
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final success = await ref
        .read(channelDetailProvider.notifier)
        .publishMessage(content: content, msgType: ChannelMessageType.text);

    if (success) {
      if (mounted) {
        _messageController.clear();
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.channel.publishFailed)));
    }
  }

  /// 处理录制的频道语音消息发送
  Future<void> _handleVoiceRecordFinished(AudioFile? obj) async {
    if (obj == null) return;
    final t = context.t;
    final Uint8List bytes = await obj.file.readAsBytes();
    if (bytes.isEmpty) return;

    setState(() => _isUploadingMedia = true);
    AppLoading.show(status: t.common.loading);

    try {
      final String mime = obj.mimeType;
      final String ext = mime.contains('/') ? mime.split('/').last : 'mp3';
      final String name = '${Xid().toString()}.$ext';

      // 1. 上传音频文件到 S3
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        name,
        mime,
        process: false,
      );
      final String? uploadedUri = meta['object_key'] as String?;

      if (uploadedUri != null && uploadedUri.isNotEmpty) {
        // 2. 发送频道消息，msgType 为 ChannelMessageType.audio
        final success = await ref
            .read(channelDetailProvider.notifier)
            .publishMessage(
              content: '',
              msgType: ChannelMessageType.audio,
              payload: {
                'uri': uploadedUri,
                'duration_ms': obj.duration.inMilliseconds,
                'size': bytes.length,
                'waveform': obj.waveform,
              },
            );

        if (success) {
          AppLoading.showSuccess(t.common.tipSuccess);
        } else {
          AppLoading.showError(t.channel.publishFailed);
        }
      } else {
        AppLoading.showError(t.common.uploadFailed);
      }
    } catch (e) {
      AppLoading.showError(t.common.voiceSendFailed);
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
      AppLoading.dismiss();
    }
  }

  /// 选择并发送媒体文件
  Future<void> _pickAndSendMedia(ChannelModel channel) async {
    if (ref.read(channelDetailProvider).isPublishing || _isUploadingMedia) {
      return;
    }
    if (mounted) {
      setState(() => _isUploadingMedia = true);
    }

    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 9,
        requestType: RequestType.common,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );

    if (assets == null || assets.isEmpty) {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
      return;
    }

    try {
      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        // 根据类型发送不同消息
        String msgType = ChannelMessageType.file;
        String uploadPrefix = 'files';
        Map<String, dynamic> payload = {
          'name': asset.title ?? file.path.split('/').last,
          'size': await file.length(),
        };

        if (asset.type == AssetType.image) {
          msgType = ChannelMessageType.image;
          uploadPrefix = 'img';
        } else if (asset.type == AssetType.video) {
          msgType = ChannelMessageType.video;
          uploadPrefix = 'camera';
          payload['duration'] = asset.duration;
        }

        final uploadedUri = await _uploadChannelFile(
          file,
          prefix: uploadPrefix,
        );
        if (!mounted) return;
        if (uploadedUri == null || uploadedUri.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.common.uploadFailed)),
          );
          continue;
        }

        payload['uri'] = uploadedUri;
        if (msgType == ChannelMessageType.video) {
          final thumbData = await asset.thumbnailDataWithSize(
            const ThumbnailSize(480, 480),
            quality: 75,
          );
          final thumbUri = thumbData == null
              ? null
              : await _uploadChannelBytes(
                  thumbData,
                  prefix: uploadPrefix,
                  path: 'thumb.jpg',
                );
          if (thumbUri != null && thumbUri.isNotEmpty) {
            payload['thumb'] = {'uri': thumbUri};
          } else {
            payload['thumb'] = {'uri': ''};
          }
        }

        final fileName = asset.title ?? file.path.split('/').last;
        final content = (fileName).trim().isEmpty ? '[media]' : fileName;

        final success = await ref
            .read(channelDetailProvider.notifier)
            .publishMessage(
              content: content,
              msgType: msgType,
              payload: payload,
            );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.channel.publishFailed)),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  Future<String?> _uploadChannelBytes(
    Uint8List file, {
    required String prefix,
    String path = 'file.jpg',
  }) async {
    String? uploadedUrl;
    final completer = Completer<bool>();

    await AttachmentApi.uploadBytesViaPresignCompat(
      prefix,
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
      path: path,
      process: false,
    );

    final success = await completer.future;
    if (!success) return null;
    return uploadedUrl;
  }

  Future<String?> _uploadChannelFile(
    File file, {
    required String prefix,
  }) async {
    String? uploadedUrl;
    final completer = Completer<bool>();

    await AttachmentApi.uploadFileViaPresignCompat(
      prefix,
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
    if (!success) return null;
    return uploadedUrl;
  }

  /// 显示频道设置
  void _showChannelSettings(ChannelModel channel) {
    final channelId = _resolveChannelId(channel);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: AppSpacing.allRegular,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getIosSeparator(
                      Theme.of(context).brightness,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.verticalRegular,
              Text(
                context.t.channel.settings,
                style: context.textStyle(
                  FontSizeType.extraLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.verticalRegular,
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.t.channel.editChannel),
                subtitle: Text(context.t.channel.editChannelDesc),
                onTap: () async {
                  Navigator.pop(context);
                  await _openChannelEdit(channel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(context.t.channel.manageAdmins),
                subtitle: Text(context.t.channel.manageAdminsDesc),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/channel/$channelId/admins');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(context.t.channel.manageSubscribers),
                subtitle: Text(context.t.channel.manageSubscribersDesc),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/channel/$channelId/subscribers');
                },
              ),
              if (channel.userRole.isCreator)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.iosRed),
                  title: Text(
                    context.t.channel.deleteChannel,
                    style: TextStyle(color: AppColors.iosRed),
                  ),
                  subtitle: Text(context.t.channel.deleteChannelDesc),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteChannelDialog(channel);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示删除频道确认对话框
  void _showDeleteChannelDialog(ChannelModel channel) {
    final t = context.t;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.channel.deleteChannel),
        content: Text(t.channel.deleteChannelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _channelService.deleteChannel(
                channel.id.toString(),
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.channelDeleted)),
                );
                // 返回上一页
                context.pop();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.deleteChannelFailed)),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.iosRed),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ChannelDetailState state) {
    if (state.isLoading && state.channel == null) {
      return const ShimmerList(itemCount: 6);
    }

    if (state.error != null && state.channel == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error!),
            AppSpacing.verticalRegular,
            ElevatedButton(
              onPressed: () {
                final channel = ref.read(channelDetailProvider).channel;
                final reloadId = _resolveChannelId(channel);
                ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
              },
              child: Text(context.t.common.buttonRetry),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final reloadId = _resolveChannelId(state.channel);
        await ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
        _statsRequestedChannelId = null;
        await _loadStats(reloadId);
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 统计信息头部
          SliverToBoxAdapter(child: _buildStatsHeader()),
          if (_isPaidChannelLocked(state.channel))
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildPaidLockedView(state.channel!),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (state.messages.isEmpty && !state.isLoading) {
                    return NoDataView(
                      icon: Icons.article_outlined,
                      text: context.t.channel.noMessages,
                    );
                  }

                  final message = state.messages[index];
                  final showDate = _shouldShowDate(state.messages, index);

                  return Column(
                    children: [
                      if (showDate) _buildDateDivider(message),
                      ChannelMessageItem(
                        message: message,
                        channelId: _resolveChannelId(state.channel),
                        isManaged: state.channel?.isManaged ?? false,
                        onReactionChanged: () {
                          // 刷新统计
                          _loadStats(_resolveChannelId(state.channel));
                        },
                        onPinned: (pinned) {
                          ref
                              .read(channelDetailProvider.notifier)
                              .updateMessagePinned(
                                message.id.toString(),
                                pinned,
                              );
                        },
                        onDeleted: () {
                          ref
                              .read(channelDetailProvider.notifier)
                              .removeMessageLocally(message.id.toString());
                        },
                      ),
                    ],
                  );
                },
                childCount: state.messages.isEmpty
                    ? 1
                    : state.messages.length + (state.hasMore ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  bool _isPaidChannelLocked(ChannelModel? channel) =>
      isPaidChannelLocked(channel);

  Widget _buildPaidLockedView(ChannelModel channel) {
    return Center(
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: AppSpacing.allLarge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.borderRadiusMedium,
            border: Border.all(
              color: AppColors.iosYellow.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.iosYellow),
                  AppSpacing.horizontalSmall,
                  Expanded(
                    child: Text(
                      t.discovery.paidChannelLocked,
                      style: context.textStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.main.purchaseUnlockHint,
                style: context.textStyle(FontSizeType.normal),
              ),
              // 价格显示：后端返回 price>0 时展示具体价格，否则不展示
              if (channel.hasPrice) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.tiny),
                    Text(
                      t.main.channelPriceLabel(
                        currency: channel.currency,
                        amount: channel.priceYuan.toStringAsFixed(2),
                      ),
                      style: context.textStyle(
                        FontSizeType.subheadline,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isPaying
                          ? null
                          : () => _buyAndUnlock(channel),
                      icon: _isPaying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_cart_checkout_outlined),
                      label: Text(
                        _isPaying
                            ? t.main.payingDots
                            : t.main.purchaseAndUnlock,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showMyOrdersSheet(channel.id.toString()),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(t.main.myOrders),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 购买并解锁付费频道（编排）。
  ///
  /// 流程：查钱包余额（用于展示+预检）→ 选支付方式 → 分发：
  /// 钱包余额走真实扣款闭环；支付宝/微信占位提示即将开通（待 S4）。
  Future<void> _buyAndUnlock(ChannelModel channel) async {
    if (_isPaying) return;

    // 余额仅在频道有明确价格时查询，用于 sheet 展示与不足预检。
    int? balanceFen;
    if (channel.hasPrice) {
      final balance = await WalletApi().getBalance();
      if (!mounted) return;
      balanceFen = balance?.balance;
    }
    final balanceText = balanceFen == null
        ? null
        : '¥${(balanceFen / 100.0).toStringAsFixed(2)}';

    final method = await showChannelPaymentMethodSheet(
      context,
      walletBalanceText: balanceText,
    );
    if (method == null || !mounted) return;

    // 第三方支付：唤起原生收银台（fluwx/tobias），回调入账后轮询命中。
    if (method != 'wallet') {
      await _payChannelWithThirdParty(channel, method);
      return;
    }

    // 余额不足引导：避免直接发起注定失败的扣费订单。
    if (channel.hasPrice && balanceFen != null && balanceFen < channel.price) {
      await _showInsufficientBalanceDialog(channel, balanceFen);
      return;
    }

    await _payChannelWithWallet(channel);
  }

  /// 第三方支付：创建订单→唤起收银台→轮询→订阅成功刷新。
  ///
  /// 取消则静默返回；未配置（appId 缺失或后端二次签名未就绪）提示"即将开通"。
  Future<void> _payChannelWithThirdParty(
    ChannelModel channel,
    String method,
  ) async {
    final channelId = _resolveChannelId(channel);
    setState(() {
      _isPaying = true;
    });
    final notifier = ref.read(channelPurchaseProvider.notifier);
    try {
      final order = await notifier.purchase(channelId, paymentMethod: method);
      if (!mounted) return;

      if (order == null) {
        final result = ref.read(channelPurchaseProvider).lastLaunchResult;
        _handleThirdPartyFailure(result);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.common.purchaseSuccess)));

      await ref.read(channelListProvider.notifier).loadSubscribedChannels();
      await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
      _statsRequestedChannelId = null;
      await _loadStats(channelId);
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  /// 第三方支付失败/取消/未配置的差异化提示。
  void _handleThirdPartyFailure(PaymentLaunchResult? result) {
    switch (result) {
      case PaymentLaunchResult.notConfigured:
        AppLoading.showToast(t.account.payMethodComingSoon);
      case PaymentLaunchResult.cancelled:
        AppLoading.showToast(t.account.payCancelled);
      case PaymentLaunchResult.failed:
      case PaymentLaunchResult.success:
      case null:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.common.purchaseFailed)));
    }
  }

  /// 钱包余额支付：创建订单→支付→轮询→订阅成功刷新。
  Future<void> _payChannelWithWallet(ChannelModel channel) async {
    final channelId = _resolveChannelId(channel);
    setState(() {
      _isPaying = true;
    });

    try {
      final order = await ref
          .read(channelPurchaseProvider.notifier)
          .purchase(channelId, paymentMethod: 'wallet');
      if (!mounted) return;

      if (order == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.common.purchaseFailed)));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.common.purchaseSuccess)));

      await ref.read(channelListProvider.notifier).loadSubscribedChannels();
      await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
      _statsRequestedChannelId = null;
      await _loadStats(channelId);
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  /// 余额不足引导：提示当前余额与所需金额，并提供"去充值"入口。
  Future<void> _showInsufficientBalanceDialog(
    ChannelModel channel,
    int balanceFen,
  ) async {
    final t = context.t;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.common.insufficientBalanceTitle),
        content: Text(
          t.common.insufficientBalanceContent(
            balance: (balanceFen / 100.0).toStringAsFixed(2),
            price: channel.priceYuan.toStringAsFixed(2),
            currency: channel.currency,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 跳转钱包页充值（go_router）
              context.push('/wallet');
            },
            child: Text(t.common.goRecharge),
          ),
        ],
      ),
    );
  }

  Future<void> _showMyOrdersSheet(String channelId) async {
    final allOrders = await _channelService.getMyOrders();
    if (!mounted) return;

    final orders = allOrders
        .where((o) => o.channelId.toString() == channelId)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child: Column(
            children: [
              AppSpacing.verticalMedium,
              Text(
                t.main.myOrders,
                style: context.textStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppSpacing.verticalSmall,
              Expanded(
                child: orders.isEmpty
                    ? Center(child: Text(t.common.noOrders))
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return ListTile(
                            title: Text(order.orderNo),
                            subtitle: Text(
                              '${order.currency} ${order.amount.toStringAsFixed(2)} · '
                              '${DateTimeHelper.dateTimeFmt(order.createdAt, pattern: 'yyyy-MM-dd HH:mm', relative: false)}',
                            ),
                            trailing: Text(
                              _orderStatusLabel(order.status),
                              style: TextStyle(
                                color: _orderStatusColor(order.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _showOrderDetail(order.orderNo),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOrderDetail(String orderNo) async {
    final order = await _channelService.getOrder(orderNo);
    if (!mounted) return;

    if (order == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.common.orderDetailLoadFailed)));
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.main.orderDetail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.common.orderNoLabel(no: order.orderNo)),
            const SizedBox(height: 6),
            Text(
              t.chat.orderStatusLabel(status: _orderStatusLabel(order.status)),
            ),
            const SizedBox(height: 6),
            Text(
              t.main.orderAmountLabel(
                currency: order.currency,
                amount: order.amount.toStringAsFixed(2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.chat.orderCreatedAtLabel(
                time: DateTimeHelper.dateTimeFmt(
                  order.createdAt,
                  pattern: 'yyyy-MM-dd HH:mm:ss',
                  relative: false,
                ),
              ),
            ),
            if (order.paymentAt != null) ...[
              const SizedBox(height: 6),
              Text(
                t.chat.orderPaymentAtLabel(
                  time: DateTimeHelper.dateTimeFmt(
                    order.paymentAt!,
                    pattern: 'yyyy-MM-dd HH:mm:ss',
                    relative: false,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t.common.confirm),
          ),
        ],
      ),
    );
  }

  String _orderStatusLabel(int status) {
    switch (status) {
      case ChannelOrderStatus.pending:
        return t.chat.orderStatusPending;
      case ChannelOrderStatus.paid:
        return t.chat.orderStatusPaid;
      case ChannelOrderStatus.refunded:
        return t.chat.orderStatusRefunded;
      case ChannelOrderStatus.cancelled:
        return t.common.orderStatusCancelled;
      case ChannelOrderStatus.expired:
        return t.chat.orderStatusExpired;
      default:
        return t.common.orderStatusUnknown;
    }
  }

  Color _orderStatusColor(int status) {
    switch (status) {
      case ChannelOrderStatus.paid:
        return AppColors.iosGreen;
      case ChannelOrderStatus.pending:
        return AppColors.iosOrange;
      case ChannelOrderStatus.refunded:
      case ChannelOrderStatus.cancelled:
      case ChannelOrderStatus.expired:
        return AppColors.iosGray;
      default:
        return AppColors.iosGray;
    }
  }

  Widget _buildStatsHeader() {
    if (_stats == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.getIosSeparator(Theme.of(context).brightness),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.people_outline,
            label: context.t.channel.subscribers,
            value: _formatNumber(_stats!.subscriberCount),
          ),
          _buildStatItem(
            icon: Icons.article_outlined,
            label: context.t.channel.messages,
            value: _formatNumber(_stats!.totalMessages),
          ),
          _buildStatItem(
            icon: Icons.remove_red_eye_outlined,
            label: context.t.channel.views,
            value: _formatNumber(_stats!.totalViews),
          ),
          _buildStatItem(
            icon: Icons.thumb_up_outlined,
            label: context.t.channel.reactions,
            value: _formatNumber(_stats!.totalReactions),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final secondaryColor = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    return Column(
      children: [
        Icon(icon, size: 20, color: secondaryColor),
        AppSpacing.verticalTiny,
        Text(
          value,
          style: context.textStyle(
            FontSizeType.medium,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: context.textStyle(
            FontSizeType.caption2,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) => formatChannelNumber(number);

  bool _shouldShowDate(List<ChannelMessageModel> messages, int index) =>
      shouldShowDateDivider(messages, index);

  Widget _buildDateDivider(ChannelMessageModel message) {
    final now = DateTime.now();
    final messageDate = message.createdAt;
    final diff = now.difference(messageDate);

    String dateText;
    if (diff.inDays == 0) {
      dateText = context.t.channel.today;
    } else if (diff.inDays == 1) {
      dateText = context.t.channel.yesterday;
    } else if (diff.inDays < 7) {
      dateText = '${diff.inDays} ${context.t.channel.daysAgo}';
    } else {
      dateText = DateTimeHelper.dateTimeFmt(
        messageDate,
        pattern: 'yyyy-MM-dd',
        relative: false,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.getIosSeparator(Theme.of(context).brightness),
            borderRadius: AppRadius.borderRadiusMedium,
          ),
          child: Text(
            dateText,
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.getTextColor(
                Theme.of(context).brightness,
                isSecondary: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, ChannelModel? channel) {
    final t = context.t;
    final channelId = _resolveChannelId(channel);

    switch (action) {
      case 'unsubscribe':
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t.channel.unsubscribeConfirm),
            content: Text(t.channel.unsubscribeConfirmDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t.common.cancel),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final success = await ref
                      .read(channelListProvider.notifier)
                      .unsubscribeChannel(channelId);
                  if (success && mounted) {
                    context.pop();
                  }
                },
                child: Text(t.common.confirm),
              ),
            ],
          ),
        );
        break;
      case 'publish':
        _focusPublishInput();
        break;
      case 'share':
        _shareChannel(channel);
        break;
      case 'invitation_center':
        if (!AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation)) {
          break;
        }
        context.push('/channel/invitations');
        break;
      case 'my_orders':
        if (!AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder)) {
          break;
        }
        _showMyOrdersSheet(channelId);
        break;
      case 'edit_channel':
        if (channel != null) {
          _openChannelEdit(channel);
        }
        break;
      case 'manage_admins':
        context.push('/channel/$channelId/admins');
        break;
      case 'manage_subscribers':
        final invitationEnabled = AppFeatureRegistry.isEnabled(
          FeatureKeys.channelInvitation,
        );
        final isPrivate = channel?.type == ChannelType.private;
        context.push(
          '/channel/$channelId/subscribers',
          extra: {'canInvite': invitationEnabled && isPrivate},
        );
        break;
    }
  }

  Future<void> _openChannelEdit(ChannelModel channel) async {
    final channelId = _resolveChannelId(channel);
    final result = await context.push(
      '/channel/$channelId/edit',
      extra: channel,
    );
    if (!mounted) return;
    if (result == null || result == false) return;

    final reloadId = result is ChannelModel && result.id != 0
        ? result.id.toString()
        : _resolveChannelId(result is ChannelModel ? result : channel);

    await ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
    _statsRequestedChannelId = null;
    await _loadStats(reloadId);
  }

  /// 分享频道
  void _shareChannel(ChannelModel? channel) {
    if (channel == null) return;

    final t = context.t;
    final shareLink = 'https://imboy.pub/channel/${channel.id}';

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppSpacing.allRegular,
              child: Text(
                channel.name,
                style: context.textStyle(
                  FontSizeType.large,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(t.channel.share),
              subtitle: Text(shareLink),
              onTap: () {
                Clipboard.setData(ClipboardData(text: shareLink));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.main.copiedToClipboard)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: Text(t.account.myQrcode),
              onTap: () {
                Navigator.pop(context);
                context.push(
                  '/qrcode/channel',
                  extra: {
                    'id': channel.id,
                    'name': channel.name,
                    'avatar': channel.avatar,
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: Text(t.channel.shareToChat),
              onTap: () {
                Navigator.pop(context);
                // 跳转到选择好友页面转发频道链接
                context.push(
                  '/chat/send_to',
                  extra: {
                    'msg': {
                      'msg_type': 'channel_card',
                      'content': channel.name,
                      'payload': {
                        'channel_id': channel.id,
                        'channel_name': channel.name,
                        'channel_avatar': channel.avatar,
                        'subscriber_count': channel.subscriberCount,
                      },
                    },
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
