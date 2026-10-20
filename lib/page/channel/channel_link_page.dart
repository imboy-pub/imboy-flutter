import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/page/moment/moment_create_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:imboy/app_core/routing/channel_link.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'channel_share_payload.dart';

/// 个人、企业频道共享的资源链接页；分享不授予订阅或工作区权限。
class ChannelLinkPage extends StatelessWidget {
  const ChannelLinkPage({super.key, required this.channel});
  final ChannelModel channel;

  @override
  Widget build(BuildContext context) {
    final link = channelLink(channel.id.toString());
    return IosPageTemplate(
      title: context.t.channel.linkTitle,
      useLargeTitle: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _identity(context),
            AppSpacing.verticalRegular,
            SelectableText(link, style: context.textStyle(FontSizeType.medium)),
            AppSpacing.verticalRegular,
            Text(context.t.channel.linkAccessHint),
            AppSpacing.verticalRegular,
            ..._actions(context, link),
          ],
        ),
      ),
    );
  }

  Widget _identity(BuildContext context) {
    final scope = channel.scope == 'workspace'
        ? context.t.channel.enterpriseChannelLabel
        : channel.scope == 'personal'
        ? context.t.channel.personalChannelLabel
        : context.t.channel.title;
    final visibility =
        channel.scope != 'workspace' && channel.hasSupportedAccessPolicy
        ? ' · ${channel.isPublic ? context.t.channel.typePublic : context.t.channel.typePrivate}'
        : '';
    return Row(
      children: [
        _avatar(),
        AppSpacing.horizontalMedium,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyle(
                  FontSizeType.large,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.verticalTiny,
              Text(
                '$scope$visibility',
                style: context.textStyle(FontSizeType.footnote),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar() => channel.avatar?.isNotEmpty == true
      ? Avatar(
          imgUri: channel.avatar!,
          width: AppSpacing.xxxLarge,
          height: AppSpacing.xxxLarge,
        )
      : CircleAvatar(
          radius: AppSpacing.xLarge,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(
            CupertinoIcons.antenna_radiowaves_left_right,
            color: AppColors.primary,
          ),
        );

  List<Widget> _actions(BuildContext context, String link) => [
    if (channel.scope == 'personal' &&
        channel.isPublic &&
        AppFeatureRegistry.isEnabled(FeatureKeys.moment))
      _row(
        context,
        CupertinoIcons.square_pencil,
        context.t.channel.shareToMyStatus,
        () => Navigator.of(context).push<void>(
          CupertinoPageRoute(
            builder: (_) =>
                MomentCreatePage(initialText: '${channel.name}\n$link'),
          ),
        ),
      ),
    _row(
      context,
      CupertinoIcons.paperplane,
      context.t.channel.shareToChat,
      () =>
          context.push('/chat/send_to', extra: channelCardShareExtra(channel)),
    ),
    _row(
      context,
      CupertinoIcons.doc_on_doc,
      context.t.channel.copyLink,
      () => _copy(context, link),
    ),
    _row(
      context,
      CupertinoIcons.share,
      context.t.channel.shareLink,
      () => _share(context, link),
    ),
    _row(
      context,
      CupertinoIcons.qrcode,
      context.t.channel.qrcode,
      () => context.push(
        '/qrcode/channel',
        extra: {
          'id': channel.id.toString(),
          'name': channel.name,
          'avatar': channel.avatar,
        },
      ),
    ),
  ];

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(CupertinoIcons.chevron_forward),
    onTap: onTap,
  );

  Future<void> _copy(BuildContext context, String link) async {
    try {
      await Clipboard.setData(ClipboardData(text: link));
      if (context.mounted) {
        AppLoading.showToast(context.t.main.copiedToClipboard);
      }
    } on Exception {
      if (context.mounted) AppLoading.showError(context.t.common.error);
    }
  }

  Future<void> _share(BuildContext context, String link) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${channel.name}\n$link',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on Exception {
      if (context.mounted) AppLoading.showError(context.t.common.error);
    }
  }
}
