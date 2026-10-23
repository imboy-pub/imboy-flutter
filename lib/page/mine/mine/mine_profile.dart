import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/current_space_tile.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class MineProfile extends StatelessWidget {
  const MineProfile({
    super.key,
    required this.user,
    required this.enterprise,
    this.spaceLabel,
  });

  final UserModel? user;
  final bool enterprise;
  final String? spaceLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.regular),
    child: Row(
      children: [
        _ProfileAvatar(user: user),
        AppSpacing.horizontalMedium,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileIdentity(user: user, enterprise: enterprise),
              CurrentSpaceTile(compact: true, compactLabel: spaceLabel),
            ],
          ),
        ),
        CupertinoButton(
          key: const ValueKey('mine-qrcode'),
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(AppSizes.touchTarget),
          onPressed: () => context.push('/qrcode/user'),
          child: Icon(
            CupertinoIcons.qrcode,
            semanticLabel: context.t.account.myQrcode,
            size: AppSizes.iconSizeMedium,
            color: AppColors.getTextColor(
              Theme.of(context).brightness,
              isSecondary: true,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = user != null && strNoEmpty(user!.avatar);
    return CupertinoButton(
      key: const ValueKey('mine-avatar'),
      padding: EdgeInsets.zero,
      onPressed: () => context.push('/personal_info/profile'),
      child: Semantics(
        label: context.t.account.profile,
        image: true,
        child: _avatar(context, hasAvatar),
      ),
    );
  }

  Widget _avatar(BuildContext context, bool hasAvatar) => Container(
    width: AppSizes.avatarSizeXLarge,
    height: AppSizes.avatarSizeXLarge,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: AppRadius.borderRadiusRegular,
      image: hasAvatar
          ? DecorationImage(
              image: avatarImageProvider(user!.avatar),
              fit: BoxFit.cover,
            )
          : null,
    ),
    child: hasAvatar
        ? null
        : Center(
            child: AvatarFallbackContent(
              name: user?.nickname ?? context.t.common.unknown,
              color: AppColors.primary,
              iconSize: AppSizes.iconSizeLarge,
              textStyle: context.textStyle(FontSizeType.extraLargeTitle),
            ),
          ),
  );
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({required this.user, required this.enterprise});

  final UserModel? user;
  final bool enterprise;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t.account.profile,
    child: CupertinoButton(
      key: const ValueKey('mine-profile'),
      padding: EdgeInsets.zero,
      alignment: AlignmentDirectional.centerStart,
      minimumSize: const Size(0, AppSizes.touchTarget),
      onPressed: () => context.push('/personal_info/profile'),
      child: Row(
        children: [
          Expanded(child: _identity(context)),
          Icon(
            CupertinoIcons.chevron_right,
            size: AppSizes.iconSizeXSmall,
            color: AppColors.getTextColor(
              Theme.of(context).brightness,
              isSecondary: true,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _identity(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        user?.nickname ?? context.t.common.unknown,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.title,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextColor(Theme.of(context).brightness),
        ),
      ),
      if (!enterprise)
        Text(
          'ID: ${user?.account ?? '-'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(
            FontSizeType.small,
            color: AppColors.getTextColor(
              Theme.of(context).brightness,
              isSecondary: true,
            ),
          ),
        ),
    ],
  );
}
