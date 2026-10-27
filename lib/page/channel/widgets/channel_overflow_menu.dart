/// 频道 ⋮ 溢出菜单（standalone AppBar 与工作区 embedded 外层顶栏共用）。
///
/// 抽取自原 `_ChannelDetailPageState`：菜单动作全部为路由跳转 + Provider
/// 调用，不依赖页面 State，可独立存在。工作区频道详情页（embedded 模式）
/// 把本按钮挂到外层 AppBar，避免「外层标题 + 内层 GlassAppBar」双层头部。
library;

import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import '../channel_di_provider.dart';
import '../channel_provider.dart';
import '../channel_link_page.dart';

/// 频道分享面板（菜单「分享」与头部「分享」按钮共用）。
void showChannelShareSheet(BuildContext context, ChannelModel channel) {
  Navigator.of(context).push<void>(
    CupertinoPageRoute(builder: (_) => ChannelLinkPage(channel: channel)),
  );
}

/// 频道信息弹窗（菜单「频道信息」项）。
void showChannelInfoDialog(
  BuildContext context,
  ChannelModel channel, {
  int? subscriberCount,
}) {
  final desc = channel.description;
  final descText = (desc != null && desc.isNotEmpty)
      ? desc
      : context.t.channel.descriptionHint;
  final hasAvatar = channel.avatar != null && channel.avatar!.isNotEmpty;
  final count = subscriberCount ?? channel.subscriberCount;

  showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Row(
        children: [
          if (hasAvatar)
            CircleAvatar(
              radius: 20,
              backgroundImage: cachedImageProvider(channel.avatar!),
            )
          else
            const CircleAvatar(
              radius: 20,
              child: Icon(CupertinoIcons.speaker_2),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              channel.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            descText,
            style: TextStyle(fontSize: FontSizeType.subheadline.size),
          ),
          if (channel.tags?.isNotEmpty ?? false) ...[
            AppSpacing.verticalSmall,
            Text(
              channel.tags!.map((tag) => '#$tag').join(' · '),
              style: context.textStyle(FontSizeType.small),
            ),
          ],
          AppSpacing.verticalSmall,
          Text(
            '${channel.isPublic ? context.t.channel.typePublic : context.t.channel.typePrivate}'
            ' · ${channel.hasPrice ? context.t.channel.accessTypePaid : context.t.channel.accessTypeFree}',
            style: context.textStyle(FontSizeType.small),
          ),
          AppSpacing.verticalRegular,
          Text(
            '${context.t.channel.subscribers}: $count',
            style: TextStyle(
              fontSize: FontSizeType.footnote.size,
              color: AppColors.iosGray,
            ),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () {
            Navigator.pop(context);
            showChannelShareSheet(context, channel);
          },
          child: Text(context.t.channel.share),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.common.ok),
        ),
      ],
    ),
  );
}

/// 退订确认弹窗：true = 用户确认退订。
Future<bool> confirmChannelUnsubscribe(BuildContext context) async {
  final t = context.t;
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(t.channel.unsubscribeConfirm),
      content: Text(t.channel.unsubscribeConfirmDesc),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t.common.cancel),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t.common.confirm),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class ChannelOverflowMenu extends ConsumerStatefulWidget {
  const ChannelOverflowMenu({
    super.key,
    required this.channel,
    this.subscriberCount,
  });

  final ChannelModel channel;

  /// 统计订阅数（可选；缺省回退 channel.subscriberCount）。
  final int? subscriberCount;

  @override
  ConsumerState<ChannelOverflowMenu> createState() =>
      _ChannelOverflowMenuState();
}

class _ChannelOverflowMenuState extends ConsumerState<ChannelOverflowMenu> {
  /// 防重入（对齐详情页 QA#29：菜单关闭瞬间连点不得叠两层 dialog）。
  bool _busy = false;

  ChannelModel get _channel => widget.channel;

  String get _channelId {
    final id = _channel.id;
    return id != 0 ? id.toString() : '';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(CupertinoIcons.ellipsis_vertical),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.medium),
      ),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceContainerHighest
          : AppColors.lightSurface,
      elevation: 2.0,
      offset: const Offset(0, 48), // Float elegantly below the app bar
      onSelected: _handleMenuAction,
      itemBuilder: _buildMenuItems,
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String text,
    Color? iconColor,
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ??
        (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final effectiveTextColor =
        textColor ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: effectiveIconColor),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: FontSizeType.medium.size,
              fontWeight: FontWeight.w400,
              color: effectiveTextColor,
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    final t = context.t;
    final channel = _channel;
    final items = <PopupMenuEntry<String>>[];
    if (channel.isManaged) {
      // 1. Channel Info / 频道信息
      items.add(
        _buildPopupMenuItem(
          value: 'show_channel_info',
          icon: CupertinoIcons.info_circle,
          text: t.channel.info,
        ),
      );

      // 2. Share / 分享
      items.add(
        _buildPopupMenuItem(
          value: 'share',
          icon: CupertinoIcons.share,
          text: t.channel.share,
        ),
      );

      // 2b. Channel QR code / 频道二维码（直达，不必再经分享面板二跳）
      items.add(
        _buildPopupMenuItem(
          value: 'channel_qrcode',
          icon: CupertinoIcons.qrcode,
          text: t.channel.qrcode,
        ),
      );

      // 3. Invite Admins / 邀请管理员
      items.add(
        _buildPopupMenuItem(
          value: 'manage_admins',
          icon: CupertinoIcons.add,
          text: t.channel.inviteAdmins,
        ),
      );

      // 4. Channel Settings / 频道设置
      items.add(
        _buildPopupMenuItem(
          value: 'edit_channel',
          icon: CupertinoIcons.gear,
          text: t.channel.settings,
        ),
      );
    } else {
      // Normal subscriber / visitor view
      // 1. Channel Info
      items.add(
        _buildPopupMenuItem(
          value: 'show_channel_info',
          icon: CupertinoIcons.info_circle,
          text: t.channel.info,
        ),
      );

      // 2. Share
      items.add(
        _buildPopupMenuItem(
          value: 'share',
          icon: CupertinoIcons.share,
          text: t.channel.share,
        ),
      );

      // 2b. Channel QR code（订阅者/访客同样可出示频道码）
      items.add(
        _buildPopupMenuItem(
          value: 'channel_qrcode',
          icon: CupertinoIcons.qrcode,
          text: t.channel.qrcode,
        ),
      );

      // 3. Unsubscribe
      if (channel.isSubscribed) {
        items.add(
          _buildPopupMenuItem(
            value: 'unsubscribe',
            icon: CupertinoIcons.bell_slash,
            text: t.channel.unsubscribe,
          ),
        );
      }

      // 4. My Orders
      if (channel.isPaid &&
          AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder)) {
        items.add(
          _buildPopupMenuItem(
            value: 'my_orders',
            icon: CupertinoIcons.doc_plaintext,
            text: t.main.myOrders,
          ),
        );
      }
    }

    return items;
  }

  void _handleMenuAction(String action) {
    final channel = _channel;
    final channelId = _channelId;

    switch (action) {
      case 'unsubscribe':
        _unsubscribe(channel);
        break;
      case 'share':
        showChannelShareSheet(context, channel);
        break;
      case 'channel_qrcode':
        // 与频道链接页同一路由契约（id 以字符串传递）。
        context.push(
          '/qrcode/channel',
          extra: {
            'id': channelId,
            'name': channel.name,
            'avatar': channel.avatar,
          },
        );
        break;
      case 'invitation_center':
        if (AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation)) {
          context.push('/channel/invitations');
        }
        break;
      case 'my_orders':
        // 委托给付费视图内的订单 sheet 不适用，这里直接跳订单页
        context.push('/channel/orders');
        break;
      case 'edit_channel':
        _openChannelEdit(channel);
        break;
      case 'show_channel_info':
        showChannelInfoDialog(
          context,
          channel,
          subscriberCount: widget.subscriberCount,
        );
        break;
      case 'publish_article':
        context.push('/channel/$channelId/compose');
        break;
      case 'manage_admins':
        context.push('/channel/$channelId/admins');
        break;
      case 'manage_subscribers':
        final invitationEnabled = AppFeatureRegistry.isEnabled(
          FeatureKeys.channelInvitation,
        );
        final canInvite =
            channel.isPrivate == true &&
            (channel.joinPolicy == 1 || channel.joinPolicy == 3);
        context.push(
          '/channel/$channelId/subscribers',
          extra: {'canInvite': invitationEnabled && canInvite},
        );
        break;
    }
  }

  Future<void> _unsubscribe(ChannelModel channel) async {
    if (_busy) return;
    final target = _channelId;
    final user = UserRepoLocal.to;
    final uid = user.currentUid;
    final generation = user.sessionGeneration;
    bool isCurrent() =>
        mounted &&
        _channelId == target &&
        user.currentUid == uid &&
        user.isCurrentSession(generation) &&
        !user.isAuthTransitioning;
    _busy = true;
    try {
      final service = ref.read(channelServiceProvider);
      if (service.hasPendingSubscription(target)) {
        final result = await ref
            .read(channelListProvider.notifier)
            .subscribeChannel(target);
        if (!isCurrent()) return;
        if (mounted && result == ChannelSubscribeOutcome.pending) {
          AppLoading.showToast(context.t.channel.subscribePending);
        } else if (mounted && result == ChannelSubscribeOutcome.completed) {
          await ref.read(channelDetailProvider.notifier).loadChannel(target);
        }
        return;
      }
      final confirmed = await confirmChannelUnsubscribe(context);
      if (!confirmed || !mounted) return;
      final success = await ref
          .read(channelListProvider.notifier)
          .unsubscribeChannel(_channelId);
      if (success && mounted) {
        await ref.read(channelDetailProvider.notifier).loadChannel(_channelId);
        // 与订阅成功/发现页退订保持对称的成功反馈（M9）
        if (mounted) {
          AppLoading.showToast(context.t.common.tipSuccess);
        }
      }
      // 失败分支不再叠兜底文案：后端中文原因已由 ChannelApi.unsubscribe 透出
    } finally {
      _busy = false;
    }
  }

  Future<void> _openChannelEdit(ChannelModel channel) async {
    final result = await context.push(
      '/channel/$_channelId/edit',
      extra: channel,
    );
    if (!mounted || result == null || result == false) return;

    final reloadId = result is ChannelModel && result.id != 0
        ? result.id.toString()
        : _channelId;

    await ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
  }
}
